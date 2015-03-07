# -*- encoding: utf-8 -*-
require 'sinatra'

require_relative './lib/razor/initialize'
require_relative './lib/razor'

class Razor::App < Sinatra::Base
  extend Razor::Validation

  configure do
    # FIXME: This turns off template caching all together since I am not
    # sure that the caching won't interfere with how we lookup
    # templates. Need to investigate whether this really is an issue, and
    # hopefully can enable template caching (which does not happen in
    # development mode anyway)
    set :reload_templates, true

    use Razor::Middleware::Logger
    use Rack::CommonLogger, TorqueBox::Logger.new("razor.web.log")

    # We add the authentication middleware all the time, so that our calls to,
    # eg, get the subject work.  The middleware is responsible for binding
    # into place our security manager and subject instance.  We only protect
    # paths if security is enabled, though.
    use Razor::Middleware::Auth, %r{/api($|/)}i

    set :show_exceptions, false
  end

  MigrationNeeded = _(
"Hey.  Your database migrations are not current!  Without them being at the
exact expected version you can expect all sorts of random looking failures.

You should rerun the migrations now.  That will fix things and stop this
error from getting in your way.  That is done with the `razor-admin` command,
and requires full control over the database (eg: add and remove tables):

    ] razor-admin migrate-database
")

  before do
    # Verify that our migrations are current and functional, and if not,
    # return a clear error message to the user.
    unless Razor.database_is_current?
      content_type 'text/plain'
      halt [500, MigrationNeeded]
    end
  end

  before do
    # We serve static files from /svc/repo and will therefore let that
    # handler determine the most appropriate content type
    pass if request.path_info.start_with?("/svc/repo")
    # Set our content type: like many people, we simply don't negotiate.
    content_type 'application/json'
  end

  before %r'/api($|/)'i do
    # Ensure that we can happily talk application/json with the client.
    # At least this way we tell you when we are going to be mean.
    #
    # This should read `request.accept?(application/json)`, but
    # unfortunately for us, https://github.com/sinatra/sinatra/issues/731
    # --daniel 2013-06-26
    request.preferred_type('application/json') or
      halt [406, {"error" => _("only application/json content is available")}.to_json]

    if Razor.config['secure_api']
      request.secure? or halt [404, {"error" => _("API requests must be over SSL (secure_api config property is enabled)")}.to_json]
    end
  end

  #
  # Server/node API
  #
  helpers do
    # Return the current user of our service, a Shiro object.
    #
    # If authentication is disabled this will always be the null user, neither
    # authentication nor remembered, and with no permissions.
    def user
      org.apache.shiro.SecurityUtils.subject
    end

    # Assert that the current user has (all of) the specified permissions, and
    # raise an exception if they do not.  We handle that exception generically
    # at the top level.
    #
    # If security is disabled then this simply succeeds.
    def check_permissions!(*which)
      Razor.config['auth.enabled'] and user.check_permissions(*which)
      true
    end

    def error(status, body = {})
      halt status, body.to_json
    end

    def json_body
      if request.content_type =~ %r'application/json'i
        return JSON.parse(request.body.read)
      else
        error 415, :error => _("only application/json is accepted here")
      end
    rescue => e
      error 400, :error => _("unable to parse JSON"), :details => e.to_s
    end

    def compose_url(*parts)
      escaped = '/' + parts.compact.map{|x|URI::escape(x.to_s)}.join('/')
      url escaped.gsub(%r'//+', '/')
    end

    def file_url(template, raw = false)
      if raw
        url "/svc/file/#{@node.id}/raw/#{URI::escape(template)}"
      else
        url "/svc/file/#{@node.id}/#{URI::escape(template)}"
      end
    end

    def log_url(msg, severity=:info)
      q = ::URI::encode_www_form(:msg => msg, :severity => severity)
      url "/svc/log/#{@node.id}?#{q}"
    end

    def store_url(vars)
      store_metadata_url('update' => vars)
    end

    def store_metadata_url(vars)
      #vars should be a hash with update and remove keys.
      q = vars.map { |k,v|
        if k == 'update' and v.is_a? Hash
          v.map { |key,val|
           "#{key}=#{val}"
          }.join("&")
        elsif k == 'remove' and v.is_a? Array
          v.map { |r|
            "remove[]=#{r}"
          }.join("&")
        else
          halt 404, _("store_metadata_url must include update and/or remove keys")
        end
      }.join("&")
      url "/svc/store_metadata/#{@node.id}?#{q}"
    end

    def broker_install_url(script = nil)
      args = "?script=#{script}" unless script.nil?
      url "/svc/broker/#{@node.id}/install#{args}"
    end

    def node_url
      url "/api/nodes/#{@node.id}"
    end

    # Produce a URL to +path+ within the current repo; this is done by
    # appending +path+ to the repo's URL. Note that that this is simply a
    # string append, and does not do proper URI concatenation in the sense
    # of +URI::join+
    def repo_url(path = "")
      if @repo.url
        url = URI::parse(@repo.url)
        url.path = (url.path + "/" + path).gsub(%r'//+', '/')
        url.to_s
      else
        compose_url "/svc/repo", @repo.name, path
      end
    end

    def repo_uri(path = "")
      URI::parse(repo_url(path))
    end

    def repo_file(path = "")
      root = File.expand_path(@repo.name, Razor.config['repo_store_root'])
      if path.empty?
        root
      else
        logger.info("repo_file(#{path.inspect})")
        Razor::Data::Repo.find_file_ignoring_case(root, path)
      end
    end

    # @todo lutter 2013-08-21: all the tasks need to be adapted to do a
    # 'curl <%= stage_done_url %> to signal that they are ready to proceed to
    # the next stage in the boot sequence
    def stage_done_url(name = "")
      url "/svc/stage-done/#{@node.id}?name=#{name}"
    end

    def config
      @config ||= Razor::Util::TemplateConfig.new
    end

    # Construct the URL that our iPXE bootstrap script should use to call
    # /svc/boot. Attempt to include as much information about the node as
    # iPXE can give us
    def ipxe_boot_url
      vars = {}
      (1..@nic_max).each do |index|
        net_id = "net#{index - 1}"
        vars[net_id] = "${#{net_id}/mac:hexhyp}"
      end
      ["dhcp_mac", "serial", "asset", "uuid"].each { |k| vars[k] = "${#{k}}" }
      q = vars.map { |k,v| "#{k}=#{v}" }.join("&")
      # Sinatra's URL generation is not robust, meaning changes need to happen
      # as string substitutions.
      (url "/svc/boot?#{q}").
           sub(/\Ahttps:/, 'http:').
           # The port may be either absent or present; make the paths converge
           sub(/\/\/#{request.host_with_port}/, "//#{request.host}").
           sub(/http:\/\/#{request.host}/, "http://#{request.host}:#{@bootstrap_port}")
    end

    # Information to include on the microkernel kernel command line that
    # the MK agent uses to identify the node
    def microkernel_kernel_args
      "razor.register=#{url("/svc/checkin/#{@node.id}")}" +
        " razor.extend=#{url('/svc/mk/extension.zip')}" +
        " #{Razor.config["microkernel.kernel_args"]}"
    end
  end

  # Client API helpers
  helpers Razor::View

  # Error handlers for node API
  error Razor::TemplateNotFoundError do
    status [404, {error: env["sinatra.error"].to_s}.to_json]
  end

  error Razor::Util::ConfigAccessProhibited do
    status [500, {error: env["sinatra.error"].to_s}.to_json]
  end

  error org.apache.shiro.authz.UnauthorizedException do
    status [403, {error: env["sinatra.error"].to_s}.to_json]
  end

  [ArgumentError, TypeError, Sequel::ValidationFailed, Sequel::Error].each do |fault|
    error fault do
      e = env["sinatra.error"]
      status [400, {error: e.to_s}.to_json]
    end
  end

  error Razor::ValidationFailure do
    e = env["sinatra.error"]
    status [e.status, {error: e.to_s}.to_json]
  end

  error Razor::Conflict do
    status [409, {error: env['sinatra.error'].to_s}.to_json]
  end


  # Convenience for /svc/boot and /svc/file
  def render_template(name)
    locals = { :task => @task, :node => @node, :repo => @repo }
    content_type 'text/plain'
    template, opts = @task.find_template(name)
    erb template, opts.merge(locals: locals, layout: false)
  end

  # FIXME: We report various errors without a body. We need to include both
  # human-readable error indications and some sort of machine-usable error
  # messages, possibly along the lines of
  # http://www.mnot.net/blog/2013/05/15/http_problem

  # API for MK

  # Receive the current facts from a node running the Microkernel, and update
  # our internal records. This also returns, synchronously, the next action
  # that the MK client should perform.
  #
  # The request should be POSTed, and contain `application/json` content.
  # The object MUST be a map, and MUST contain the following fields:
  #
  # * `hw_id`: the "hardware" ID value for the machine; this is a
  #   transformation of Ethernet-ish looking interface MAC values as
  #   discovered by the Linux MK client.
  # * `facts`: a map of fact names to fact values.
  #
  # @todo danielp 2013-07-29: ...and we don't, yet, actually return anything
  # meaningful.  In practice, I strongly suspect that we should be splitting
  # out "do this" from "register me", as this presently forbids multiple
  # actions being queued for the MK, and so on.  (At least, without inventing
  # a custom bundling format for them...)
  #
  # @todo lutter 2013-09-04: this code assumes that we can tell an MK its
  # unique checkin URL, which is true for MK's that boot through
  # +tasks/microkernel/boot.erb+. If we need to allow booting of MK's by
  # other means, we'd need to convince facter to send us the same hw_info that
  # iPXE does and identify the node via +Node.lookup+
  post '/svc/checkin/:id' do
    logger.info("checkin by node #{params[:id]}")
    return 400 if request.content_type != 'application/json'
    begin
      json = JSON::parse(request.body.read)
    rescue JSON::ParserError
      return 400
    end
    return 400 unless json['facts']
    begin
      node = Razor::Data::Node[params["id"]] or return 404
      unless node.registered?
        # This is a newly created node (created by /svc/boot) and we haven't
        # fully identified it yet. Since the facts tell us much more about
        # the node than iPXE does, look the node up again, which, as a
        # sideeffect will amend the node's hw_info
        node = Razor::Data::Node.register(json['facts'])
        return 404 unless node
      end
      node.checkin(json).to_json
    rescue Razor::Data::DuplicateNodeError => e
      # Raised by register
      e.log_to_nodes!
      logger.error(e.message)
      return 400
    rescue Razor::Matcher::RuleEvaluationError => e
      logger.error("during checkin of #{node.name}: " + e.message)
      { :action => :none }.to_json
    end
  end

  # Take a hardware ID bundle, match it to a node, and return the unique node
  # ID.  This is for the benefit of the Windows installer client, which can't
  # take any dynamic content from the boot loader, and potentially any future
  # task (or other utility) which can identify the hardware details, but not
  # the node ID, to get that ID.
  #
  # GET the URL, with `netN` keys for your network cards, and optionally a
  # `dhcp_mac`, serial, asset, and uuid DMI data arguments.  These are used
  # for the same node matching as done in the `/svc/boot` process.
  #
  # The return value is a JSON object with one key, `id`, containing the
  # unique node ID used for further transactions.
  #
  # Typically this will then be used to access `/srv/file/$node_id/...`
  # content from the service.
  get '/svc/nodeid' do
    return 400 if params.empty?
    begin
      if node = Razor::Data::Node.lookup(params)
        logger.info("/svc/nodeid: #{params.inspect} mapped to #{node.id}")
        { :id => node.id }.to_json
      else
        logger.info("/svc/nodeid: #{params.inspect} not found")
        404
      end
    rescue Razor::Data::DuplicateNodeError => e
      logger.info("/svc/nodeid: #{params.inspect} multiple nodes")
      e.log_to_nodes!
      logger.error(e.message)
      return 400
    end
  end

  get '/svc/boot' do
    begin
      @node = Razor::Data::Node.lookup(params)
    rescue Razor::Data::DuplicateNodeError => e
      e.log_to_nodes!
      logger.error(e.message)
      return 400
    rescue ArgumentError => e
      logger.error(e.message)
      return 400
    end

    @task = @node.task
    template = @task.boot_template(@node)

    if @node.policy
      @repo = @node.policy.repo
      @node.log_append(:event => :boot, :task => @task.name,
                       :template => template, :repo => @repo.name)
    else
      # @todo lutter 2013-08-19: We have no policy on the node, and will
      # therefore boot into the MK. This is a gigantic hack; all we need is
      # an repo with the right name so that the repo_url helper generates
      # links to the microkernel directory in the repo store.
      #
      # We do not have API support yet to set up MK's, and users therefore
      # have to put the kernel and initrd into the microkernel/ directory
      # in their repo store manually for things to work.
      @repo = Razor::Data::Repo.new(:name => "microkernel",
                                    :iso_url => "file:///dev/null",
                                    :task_name => @task.name)

      @node.log_append(:event => :boot, :task => @task.name,
                       :template => template)
    end
    @node.save
    Razor::Data::Hook.run('node-booted', node: @node)
    render_template(template)
  end

  get '/svc/file/:node_id/raw/:filename' do
    logger.info("#{params[:node_id]}: raw file #{params[:filename]}")

    halt 404 if params[:filename] =~ /\.erb$/i # no raw template access

    @node = Razor::Data::Node[params[:node_id]]
    halt 404 unless @node

    halt 409 unless @node.policy

    @task = @node.task
    @repo = @node.policy.repo

    begin
      fpath = @task.find_file(params[:filename])
    rescue Razor::TemplateNotFoundError => e
      @node.log_append(:event => :get_raw_file,
                       :msg => _("raw task file %{script} not found") % {script: params[:filename]},
                       :severity => 'error', :url => request.url)
      raise e
    end

    unless fpath
    end
    @node.log_append(:event => :get_raw_file, :template => params[:filename],
                     :url => request.url)

    content_type nil
    send_file fpath, :disposition => nil
  end

  get '/svc/file/:node_id/:template' do
    logger.info("request from #{params[:node_id]} for #{params[:template]}")
    @node = Razor::Data::Node[params[:node_id]]
    halt 404 unless @node

    halt 409 unless @node.policy

    @task = @node.task
    @repo = @node.policy.repo

    begin
      render_template(params[:template]).tap do |_|
          @node.log_append(:event => :get_task_file, :template => params[:template],
                           :url => request.url)
      end
    rescue Razor::TemplateNotFoundError => e
      @node.log_append(:event => :get_task_file, :script => params[:template],
                       :msg => _("task file %{script} not found") % {script: params[:template]},
                       :severity => 'error', :url => request.url)
      raise e
    end
  end

  # This accepts a `script` parameter, which defaults to `install` for the file `install.erb`.
  get '/svc/broker/:node_id/install' do
    @node = Razor::Data::Node[params[:node_id]]
    halt 404 unless @node
    error 409, :error => _("node %{node} not bound to a policy yet") % {node: @node.id} unless @node.policy

    content_type 'text/plain'   # @todo danielp 2013-09-24: ...or?
    script_name = params['script'] || 'install'
    begin
      # The stage_done_url needs to be generated in Sinatra, so we calculate it here and pass it on.
      stage_done_url = stage_done_url('broker')
      @node.policy.broker.install_script_for(@node, script_name,
                                            'stage_done_url' => stage_done_url).tap do |_|
        @node.log_append(:event => :get_broker_file,
                         :script => script_name, :url => request.url)
      end
    rescue Razor::InstallTemplateNotFoundError => e
      @node.log_append(:event => :get_broker_file,
                       :msg => _("broker install file %{script} not found") % {script: script_name},
                       :severity => 'error', :url => request.url)
      error 404, :error => _("install template %{name}.erb does not exist") % {name: script_name},
            :details => e.to_s
    end
  end

  get '/svc/log/:node_id' do
    node = Razor::Data::Node[params[:node_id]] if params[:node_id]
    unless node
      Razor::Data::Event.log_append(:event => :get_broker_file,
                     :msg => _("node %{node} not found to log") % {node: params[:node_id]},
                     :severity => 'error', :original_msg => params[:msg])
      error 404, :error => _("node %{node}.erb does not exist") % {node: params[:node_id]}
    end
    entry = {:msg => params[:msg]}
    entry = JSON::parse(entry.to_json)
    event = Razor::Data::Event.new({:entry => entry})
    event.severity = params[:severity] || 'info'
    event.node = node
    event.save
    [204, {}]
  end

  get '/svc/store_metadata/:node_id' do
    #Clean the params.
    params.delete('splat')
    params.delete('captures')

    id = params.delete('node_id')
    node = Razor::Data::Node[id]
    halt 404 unless node

    modify_data = Hash.new
    modify_data['remove'] = params.delete('remove') unless params['remove'].nil?
    modify_data['update'] = params unless params.nil?

    node.modify_metadata(modify_data)
    node.log_append(:event => :store_metadata, :vars => modify_data )
    [204, {}]
  end

  get '/svc/stage-done/:node_id' do
    Razor::Data::Node.stage_done(params[:node_id], params[:name])
    [204, {}]
  end

  get '/svc/repo/*' do |path|
    root = File.expand_path(Razor.config['repo_store_root'])

    # Unfortunately, we face some complexities.  The ISO9660 format only
    # supports upper-case filenames, but some tasks assume they will be
    # mapped to lower-case automatically.  If that doesn't happen, we can
    # hit trouble.  So, to make this more user friendly we look for a
    # case-insensitive match on the file.
    fpath = Razor::Data::Repo.find_file_ignoring_case(root, path)
    if fpath and fpath.start_with?(root) and File.file?(fpath)
      content_type nil
      send_file fpath, :disposition => nil
    else
      # This method is called so many times that we only want to report errors.
      Razor::Data::Event.log_append(:event => :get_file,
          :msg => _("repo file %{path} not found") % {path: path}, :severity => 'error',
          :url => request.url)
      [404, { :error => _("File %{path} not found") % {path: path} }.to_json ]
    end
  end

  get '/svc/mk/extension.zip' do
    path = Razor.config['microkernel.extension-zip']
    if path and File.readable?(path) and File.file?(path)
      send_file path, {
        type:        'application/zip',
        disposition: :attachment,
        filename:    'extension.zip',
        status:      200
      }
    else
      content_type 'application/json'
      [404, {:error => _('No extension file configured')}.to_json]
    end
  end

  # The collections we advertise in the API
  #
  # @todo danielp 2013-06-26: this should be some sort of discovery, not a
  # hand-coded list, but ... it will do, for now.
  COLLECTIONS = [:brokers, :repos, :tags, :policies,
                 [:nodes, {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}], :tasks, :commands,
                 [:events, {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}], :hooks]

  #
  # The main entry point for the public/management API
  #
  get '/api' do
    # `rel` is the relationship; by RFC5988 (Web Linking) -- which is
    # designed for HTTP, but we abuse in JSON -- this is the closest we can
    # get to a conformant identifier for a custom relationship type, and
    # since we expect to consume one per command to avoid clients just
    # knowing the URL, we get this nastiness.  At least we can turn it into
    # something useful by putting documentation about how to use the
    # command or query interface behind it, I guess. --daniel 2013-06-26
    #
    # @todo danielp 2013-11-15: we should use `href` or similar rather than
    # `id` to point to the URL you end up following.  That makes way
    # more sense.  See https://github.com/puppetlabs/razor-server/issues/96
    # for discussion and compatibility concerns; we also want to preserve the
    # `id` key for some time so we don't break older clients.
    {
      "commands" => Razor::Command.all.map(&:to_command_list_hash).map {|c| c.dup.update("id" => url(c["id"])) },
      "collections" => COLLECTIONS.map do |coll|
        coll, params = coll if coll.is_a?(Array)
        { "name" => coll, "rel" => spec_url("/collections/#{coll}"),
          "id" => url("/api/collections/#{coll}"),
          "params" => params }.delete_if { |_, v| v.nil? }
      end,
      "version" => { "server" => Razor::VERSION }
    }.to_json
  end

  # Hook all our commands into the HTTP router.
  get '/api/commands/:name', provides: 'application/json' do
    cmd = Razor::Command.find(name: params[:name]) or pass
    cmd.new.handle_http_get(self)
  end

  post '/api/commands/:name' do
    cmd = Razor::Command.find(name: params[:name]) or pass
    cmd.new.handle_http_post(self)
  end


  #
  # Query/collections API
  #

  # We can generically permission check "any read at all" on the
  # collection entries, thankfully.
  before %r{^/api/collections/([^/]+)/?([^/]+)?$}i do |collection, item|
    check_permissions!("query:#{collection}" + (item ? ":#{item}" : ''))
  end

  get '/api/collections/tags' do
    collection_view Razor::Data::Tag, "tags"
  end

  get '/api/collections/tags/:name' do
    tag = Razor::Data::Tag[:name => params[:name]] or
      error 404, :error => _("no tag matched id=%{name}") % {name: params[:name]}
    tag_hash(tag).to_json
  end

  get '/api/collections/tags/:name/nodes' do
    tag = Razor::Data::Tag[:name => params[:name]] or
      error 404, :error => _("no tag matched id=%{name}") % {name: params[:name]}
    collection_view(tag.nodes, "nodes")
  end

  get '/api/collections/tags/:name/policies' do
    tag = Razor::Data::Tag[:name => params[:name]] or
      error 404, :error => _("no tag matched id=%{name}") % {name: params[:name]}
    collection_view(tag.policies, "policies")
  end

  get '/api/collections/brokers' do
    collection_view Razor::Data::Broker, 'brokers'
  end

  get '/api/collections/brokers/:name' do
    broker = Razor::Data::Broker[:name => params[:name]] or
      halt 404, _("no broker matched id=%{name}") % {name: params[:name]}
    broker_hash(broker).to_json
  end

  get '/api/collections/brokers/:name/policies' do
    broker = Razor::Data::Broker[:name => params[:name]] or
      halt 404, _("no broker matched id=%{name}") % {name: params[:name]}
    collection_view(broker.policies, "policies")
  end

  get '/api/collections/policies' do
    collection_view Razor::Data::Policy.order(:rule_number), 'policies'
  end

  get '/api/collections/policies/:name' do
    policy = Razor::Data::Policy[:name => params[:name]] or
      error 404, :error => _("no policy matched id=%{name}") % {name: params[:name]}
    policy_hash(policy).to_json
  end

  get '/api/collections/policies/:name/nodes' do
    policy = Razor::Data::Policy[:name => params[:name]] or
      error 404, :error => _("no policy matched id=%{name}") % {name: params[:name]}
    collection_view(policy.nodes, "nodes")
  end

  get '/api/collections/tasks' do
    collection_view Razor::Task, 'tasks'
  end

  get '/api/collections/tasks/*' do |name|
    begin
      task = Razor::Task.find(name)
    rescue Razor::TaskNotFoundError => e
      error 404, :error => _("Task %{name} does not exist") % {name: name},
        :details => e.to_s
    end
    task_hash(task).to_json
  end

  get '/api/collections/repos' do
    collection_view Razor::Data::Repo, 'repos'
  end

  get '/api/collections/repos/:name' do
    repo = Razor::Data::Repo[:name => params[:name]] or
      error 404, :error => _("no repo matched name=%{name}") % {name: params[:name]}
    repo_hash(repo).to_json
  end

  get '/api/collections/commands' do
    collection_view Razor::Data::Command.order(:submitted_at).reverse,
      'commands'
  end

  get '/api/collections/commands/:id' do
    # params[:id] better look like an integer. Without this check, passing
    # in 'foo' as the id will produce a 400 error (and internal stacktrace)
    # rather than the expected 404
    params[:id].to_i.to_s == params[:id] or
      error 404, :error => _("no such command")
    cmd = Razor::Data::Command[params[:id]] or
      error 404, :error => _("no such command")
    command_hash(cmd).to_json
  end

  get '/api/collections/events' do
    check_permissions!("query:events")

    # Need to also order by ID here in case the granularity of timestamp is
    # not enough to maintain a consistent ordering.
    cursor = Razor::Data::Event.order(:timestamp).order(:id).reverse
    collection_view cursor, 'events', limit: params[:limit], start: params[:start]
  end

  get '/api/collections/events/:id' do
    params[:id] =~ /[0-9]+/ or error 400, :error => _("id must be a number but was %{id}") % {id: params[:id]}
    check_permissions!("query:events:#{params[:id]}")
    event = Razor::Data::Event[:id => params[:id]] or
        error 404, :error => _("no event matched id=%{id}") % {id: params[:id]}
    event_hash(event).to_json
  end

  get '/api/collections/hooks' do
    check_permissions!("query:hooks")

    collection_view Razor::Data::Hook, 'hooks'
  end

  get '/api/collections/hooks/:name' do
    check_permissions!("query:hooks:#{params[:name]}")
    hook = Razor::Data::Hook[:name => params[:name]] or
        error 404, :error => _("no hook matched name=%{name}") % {name: params[:name]}
    hook_hash(hook).to_json
  end

  get '/api/collections/hooks/:name/log' do
    check_permissions!("query:hooks:#{params[:name]}")
    hook = Razor::Data::Hook[:name => params[:name]] or
        error 404, :error => _("no hook matched name=%{name}") % {name: params[:name]}
    {
        "spec" => spec_url("collections", "hooks", "log"),
        "items" => hook.log(limit: params[:limit], start: params[:start])
    }.to_json
  end

  get '/api/collections/nodes' do
    collection_view Razor::Data::Node.search(params).order(:name), 'nodes', limit: params[:limit], start: params[:start]
  end

  get '/api/collections/nodes/:name' do
    node = Razor::Data::Node[:name => params[:name]] or
      error 404, :error => _("no node matched name=%{name}") % {name: params[:name]}
    node_hash(node).to_json
  end

  get '/api/collections/nodes/:name/log' do
    check_permissions!("query:nodes:#{params[:name]}:log")

    # @todo lutter 2013-08-20: There are no tests for this handler
    # @todo lutter 2013-08-20: Do we need to send the log through a view ?
    node = Razor::Data::Node[:name => params[:name]] or
      error 404, :error => _("no node matched hw_id=%{hw_id}") % {hw_id: params[:hw_id]}
    # This is not a standard collection in that each item is not just a
    # reference, instead containing relevant details to make the `/log`
    # view worthwhile without extra querying.
    {
      "spec" => spec_url("collections", "nodes", "log"),
      "items" => node.log(limit: params[:limit], start: params[:start])
    }.to_json
  end

  # @todo lutter 2013-08-18: advertise this in the entrypoint; it's neither
  # a command not a collection.
  get '/api/microkernel/bootstrap' do
    params["nic_max"].nil? or params["nic_max"] =~ /\A[1-9][0-9]*\Z/ or
      error 400,
        :error => _("The nic_max parameter must be an integer not starting with 0")

    params['http_port'].nil? and request.secure? and
      error 400,
        :error => _("The `http_port` argument must be supplied for bootstrap generation on a secure port")

    @bootstrap_port = params['http_port'].nil? ? request.port.to_s : params['http_port']

    # How many NICs ipxe should probe for DHCP
    @nic_max = params["nic_max"].nil? ? 4 : params["nic_max"].to_i

    @task = Razor::Task.mk_task

    render_template("bootstrap")
  end
end
