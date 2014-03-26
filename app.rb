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

    def broker_install_url
      url "/svc/broker/#{@node.id}/install"
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
      url "/svc/boot?#{q}"
    end

    # Information to include on the microkernel kernel command line that
    # the MK agent uses to identify the node
    def microkernel_kernel_args
      "razor.register=#{url("/svc/checkin/#{@node.id}")} #{Razor.config["microkernel.kernel_args"]}"
    end
  end

  # Client API helpers
  helpers Razor::View

  # Error handlers for node API
  error Razor::TemplateNotFoundError do
    status [404, env["sinatra.error"].message]
  end

  error Razor::Util::ConfigAccessProhibited do
    status [500, env["sinatra.error"].message]
  end

  error org.apache.shiro.authz.UnauthorizedException do
    status [403, env["sinatra.error"].to_s]
  end

  [ArgumentError, TypeError, Sequel::ValidationFailed, Sequel::Error].each do |fault|
    error fault do
      status [400, env["sinatra.error"].to_s]
    end
  end

  error Razor::ValidationFailure do
    e = env["sinatra.error"]
    status [e.status, {error: e.to_s}.to_json]
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
      node.checkin(json).to_json
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

    if @node.policy
      @repo = @node.policy.repo
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
                                    :iso_url => "file:///dev/null")
    end
    template = @task.boot_template(@node)

    @node.log_append(:event => :boot, :task => @task.name,
                     :template => template, :repo => @repo.name)
    @node.save
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

    @node.log_append(:event => :get_raw_file, :template => params[:filename],
                     :url => request.url)

    fpath = @task.find_file(params[:filename]) or halt 404
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

    @node.log_append(:event => :get_file, :template => params[:template],
                     :url => request.url)

    render_template(params[:template])
  end

  # If we support more than just the `install` script in brokers, this should
  # expand to take the template identifier like the file service does.
  get '/svc/broker/:node_id/install' do
    node = Razor::Data::Node[params[:node_id]]
    halt 404 unless node
    halt 409 unless node.policy

    content_type 'text/plain'   # @todo danielp 2013-09-24: ...or?
    node.policy.broker.install_script_for(node)
  end

  get '/svc/log/:node_id' do
    node = Razor::Data::Node[params[:node_id]]
    halt 404 unless node

    node.log_append(:event => :node_log,
                    :msg=> params[:msg], :severity => params[:severity])
    node.save
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
      [404, { :error => _("File %{path} not found") % {path: path} }.to_json ]
    end
  end

  # The collections we advertise in the API
  #
  # @todo danielp 2013-06-26: this should be some sort of discovery, not a
  # hand-coded list, but ... it will do, for now.
  COLLECTIONS = [:brokers, :repos, :tags, :policies, :nodes, :tasks]

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
      "commands" => @@commands.map { |c| c.dup.update("id" => url(c["id"])) },
      "collections" => COLLECTIONS.map do |coll|
        { "name" => coll, "rel" => spec_url("/collections/#{coll}"),
          "id" => url("/api/collections/#{coll}")}
      end
    }.to_json
  end

  # Command handling and query API: this provides navigation data to allow
  # clients to discover which URL namespace content is available, and access
  # the query and command operations they desire.

  @@commands = []

  # A helper to wire up new commands and enter them into the list of
  # commands we return from /api. The actual command handler will live
  # at '/api/commands/#{name}'. The block will be passed the body of the
  # request, already parsed into a Ruby object.
  #
  # Any exception the block may throw will lead to a response with status
  # 400. The block should return an object whose +view_object_reference+
  # will be returned in the response together with status code 202
  def self.command(name, &block)
    name = name.to_s.tr("_", "-")
    path = "/api/commands/#{name}"
    # List this command when clients ask for /api
    @@commands << {
      "name" => name,
      "rel" => Razor::View::spec_url("commands", name),
      "id" => path
    }.freeze

    # Handler for the command
    post path do
      data = json_body
      self.class.validate!(name, data)

      # @todo lutter 2013-08-18: tr("_", "-") in all keys in data
      # (recursively) so that we do not use '_' in the API (i.e., this also
      # requires fixing up view.rb)

      result = instance_exec(data, &block)
      result = view_object_reference(result) unless result.is_a?(Hash)
      [202, result.to_json]
    end
  end

  validate :create_repo do
    authz '%{name}'

    attr  'name',    type: String, required: true
    attr  'url',     type: URI,    exclude: 'iso-url'
    attr  'iso-url', type: URI,    exclude: 'url'

    require_one_of 'url', 'iso-url'
  end

  command :create_repo do |data|
    # Create our shiny new repo.  This will implicitly, thanks to saving
    # changes, trigger our loading saga to begin.  (Which takes place in the
    # same transactional context, ensuring we don't send a message to our
    # background workers without also committing this data to our database.)
    data["iso_url"] = data.delete("iso-url")
    repo = Razor::Data::Repo.new(data).save.freeze

    # Finally, return the state (started, not complete) and the URL for the
    # final repo to our poor caller, so they can watch progress happen.
    repo
  end

  validate :delete_repo do
    authz '%{name}'
    attr  'name', type: String, required: true
  end

  command :delete_repo do |data|
    if repo = Razor::Data::Repo[:name => data['name']]
      repo.destroy
      action = _("repo destroyed")
    else
      action = _("no changes; repo %{name} does not exist") % {name: data["name"]}
    end
    { :result => action }
  end

  validate :delete_node do
    authz '%{name}'
    attr  'name', type: String, required: true
  end

  command :delete_node do |data|
    if node = Razor::Data::Node[:name => data['name']]
      node.destroy
      action = _("node destroyed")
    else
      action = _("no changes; node %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end

  validate :delete_policy do
    authz '%{name}'
    attr  'name', type: String, required: true
  end

  command :delete_policy do |data|
    #deleting a policy will first remove the policy from any node
    #associated with it.  The node will remain bound, resulting in the
    #noop task being associated on boot (causing a local boot)
    if policy = Razor::Data::Policy[:name => data['name']]
      policy.remove_all_nodes
      policy.remove_all_tags
      policy.destroy
      action = _("policy destroyed")
    else
      action = _("no changes; policy %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end

  # Update/add specific metadata key (works with GET)
  command :update_node_metadata do |data|
    data['node'] or error 400,
      :error => _('must supply node')
    data['key'] or ( data['all'] and data['all'] == 'true' ) or error 400,
      :error => _('must supply key or set all to true')
    data['value'] or error 400,
      :error => _('must supply value')

    if data['no_replace']
      data['no_replace'] == true or data['no_replace'] == 'true' or error 400,
        :error => _("no_replace must be boolean true or string 'true'")
    end

    if node = Razor::Data::Node[:name => data['node']]
      operation = { 'update' => { data['key'] => data['value'] } }
      operation['no_replace'] = true unless operation['no_replace'].nil?

      node.modify_metadata(operation)
    else
      error 400, :error => "Node #{data['node']} not found"
    end
  end

  # Remove a specific key or remove all (works with GET)
  command :remove_node_metadata do |data|
    data['node'] or error 400,
      :error => _('must supply node')
    data['key'] or ( data['all'] and data['all'] == 'true' ) or error 400,
      :error => _('must supply key or set all to true')

    if node = Razor::Data::Node[:name => data['node']]
      if data['key']
        operation = { 'remove' => [ data['key'] ] }
      else
        operation = { 'clear' => true }
      end
      node.modify_metadata(operation)
    else
      error 400, :error => _("Node %{name} not found") % {name: data['node']}
    end
  end

  # Take a bulk operation via POST'ed JSON
  command :modify_node_metadata do |data|
    data['node'] or error 400,
      :error => _('must supply node')
    data['update'] or data['remove'] or data['clear'] or error 400,
      :error => _('must supply at least one opperation')

    if data['clear'] and (data['update'] or data['remove'])
      error 400, :error => _('clear cannot be used with update or remove')
    end

    if data['clear']
      data['clear'] == true or data['clear'] == 'true' or error 400,
        :error => _("clear must be boolean true or string 'true'")
    end

    if data['no_replace']
      data['no_replace'] == true or data['no_replace'] == 'true' or error 400,
        :error => _("no_replace must be boolean true or string 'true'")
    end

    if data['update'] and data['remove']
      data['update'].keys.concat(data['remove']).uniq! and error 400,
        :error => _('cannot update and remove the same key')
    end

    if node = Razor::Data::Node[:name => data.delete('node')]
      node.modify_metadata(data)
    else
      error 400, :error => _("Node %{name} not found") % {name: data['node']}
    end
  end

  validate :reinstall_node do
    authz '%{name}'
    attr  'name', type: String, required: true, references: Razor::Data::Node
  end

  command :reinstall_node do |data|
    actions = []

    node = Razor::Data::Node[:name => data['name']]
    log = { :event => :reinstall }

    if node.policy
      log[:policy_name] = node.policy.name
      node.policy = nil
      actions << _("node unbound from %{policy}") % {policy: log[:policy_name]}
    end

    if node.installed
      log[:installed] = node.installed
      node.installed = nil
      node.installed_at = nil
      actions << _("installed flag cleared")
    end

    if actions.empty?
      actions << _("no changes; node %{name} was neither bound nor installed") % {name: data['name']}
    end

    node.log_append(log)
    node.save

    # @todo danielp 2014-02-27: I don't know the best way to handle this sort
    # of conjoined string in translation.
    { :result => actions.join(_(" and ")) }
  end

  validate :set_node_ipmi_credentials do
    authz '%{name}'
    attr  'name', type: String, required: true, references: Razor::Data::Node
    attr  'ipmi-hostname', type: String
    attr  'ipmi-username', type: String, also: 'ipmi-hostname'
    attr  'ipmi-password', type: String, also: 'ipmi-hostname'
  end

  command :set_node_ipmi_credentials do |data|
    node = Razor::Data::Node[:name => data['name']]

    # Finally, save the changes.  This is using the unrestricted update
    # method because we carefully manually constructed our input above,
    # effectively doing our own input validation manually.  If you ever
    # change that (because, say, we fix the -/_ thing globally, make sure
    # you restrict this to changing the specific attributes only.
    node.update(
      :ipmi_hostname => data['ipmi-hostname'],
      :ipmi_username => data['ipmi-username'],
      :ipmi_password => data['ipmi-password'])

    { :result => _('updated IPMI details') }
  end

  validate :reboot_node do
    authz '%{name}'
    attr  'name', type: String, required: true, references: Razor::Data::Node
  end

  command :reboot_node do |data|
    node = Razor::Data::Node[:name => data['name']]

    node.ipmi_hostname or
      error 422, { :error => _("node %{name} does not have IPMI credentials set") % {name: node.name} }

    node.publish 'reboot!'

    { :result => _('reboot request queued') }
  end

  validate :set_node_desired_power_state do
    authz '%{name}'
    attr  'name', type: String, required: true,  references: Razor::Data::Node
    attr  'to',   type: [String, nil], required: false, one_of: ['on', 'off', nil]
  end

  command :set_node_desired_power_state do |data|
    node = Razor::Data::Node[:name => data['name']]

    node.set(desired_power_state: data['to']).save
    {result: _("set desired power state to %{state}") % {state: data['to'] || 'ignored (null)'}}
  end

  validate :create_task do
    authz '%{name}'
    attr  'name', type: String, required: true
    attr  'os',   type: String, required: true

    object 'templates', required: true do
      extra_attrs type: String
    end

    object 'boot_seq' do
      attr 'default', type: String
      extra_attrs /^[0-9]+/, type: String
    end
  end

  command :create_task do |data|
    check_permissions! "commands:create-task:#{data['name']}"

    # If boot_seq is not a Hash, the model validation for tasks
    # will catch that, and will make saving the task fail
    if (boot_seq = data["boot_seq"]).is_a?(Hash)
      # JSON serializes integers as strings, undo that
      boot_seq.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
        each { |k| boot_seq[k.to_i] = boot_seq.delete(k) }
    end

    Razor::Data::Task.new(data).save.freeze
  end

  validate :create_tag do
    authz '%{name}'
    attr  'name', type: String, required: true
    attr  'rule', type: Array
  end

  command :create_tag do |data|
    Razor::Data::Tag.find_or_create_with_rule(data)
  end

  validate :delete_tag do
    authz '%{name}'
    attr  'name',  type: String, required: true
    attr  'force', type: :bool
  end

  command :delete_tag do |data|
    if tag = Razor::Data::Tag[:name => data["name"]]
      data["force"] or tag.policies.empty? or
        error 400, :error => _("Tag '%{name}' is used by policies and 'force' is false") % {name: data["name"]}
      tag.remove_all_policies
      tag.remove_all_nodes
      tag.destroy
      { :result => _("Tag %{name} deleted") % {name: data["name"]} }
    else
      { :result => _("No change. Tag %{name} does not exist.") % {name: data["name"]} }
    end
  end

  validate :update_tag_rule do
    authz '%{name}'
    attr  'name',  type: String, required: true, references: Razor::Data::Tag
    attr  'rule',  type: Array
    attr  'force', type: :bool
  end

  command :update_tag_rule do |data|
    tag = Razor::Data::Tag[:name => data["name"]]
    data["force"] or tag.policies.empty? or
      error 400, :error => _("Tag '%{name}' is used by policies and 'force' is false") % {name: data["name"]}
    if tag.rule != data["rule"]
      tag.rule = data["rule"]
      tag.save
      { :result => _("Tag %{name} updated") % {name: data["name"]} }
    else
      { :result => _("No change; new rule is the same as the existing rule for %{name}") % {name: data["name"]} }
    end
  end

  validate :create_broker do
    authz  '%{name}'
    attr   'name', type: String, required: true
    attr   'broker-type', type: String, references: [Razor::BrokerType, :name]
    object 'configuration' do
      extra_attrs /./
    end
  end

  command :create_broker do |data|
    if type = data.delete("broker-type")
      data["broker_type"] = Razor::BrokerType.find(name: type) or
        halt [400, _("Broker type '%{name}' not found") % {name: type}]
    end

    Razor::Data::Broker.new(data).save
  end

  validate :delete_broker do
    authz  '%{name}'
    attr   'name', type: String, required: true
  end

  command :delete_broker do |data|
    if broker = Razor::Data::Broker[:name => data['name']]
      broker.policies.count == 0 or
        error 400, :error => _("Broker %{name} is still used by policies") % {name: broker.name}

      broker.destroy
      action = _("broker %{name} destroyed") % {name: data['name']}
    else
      action = _("no changes; broker %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end

  validate :create_policy do
    authz  '%{name}'
    attr   'name',          type: String, required: true
    attr   'hostname',      type: String, required: true
    attr   'root_password', type: String

    object 'before', exclude: 'after' do
      attr 'name', type: String, required: true, references: Razor::Data::Policy
    end

    object 'after', exclude: 'before' do
      attr 'name', type: String, required: true, references: Razor::Data::Policy
    end

    array 'tags' do
      object do
        attr 'name', type: String, required: true, references: Razor::Data::Tag
      end
    end

    object 'repo' do
      attr 'name', type: String, required: true, references: Razor::Data::Repo
    end

    object 'broker' do
      attr 'name', type: String, required: true, references: Razor::Data::Broker
    end

    object 'task' do
      attr 'name', type: String, required: true
    end
  end

  command :create_policy do |data|
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find_or_create_with_rule(t)
    end

    data["repo"]   &&= Razor::Data::Repo[:name => data["repo"]["name"]]
    data["broker"] &&= Razor::Data::Broker[:name => data["broker"]["name"]]

    if data["task"]
      data["task_name"] = data.delete("task")["name"]
    end

    data["hostname_pattern"] = data.delete("hostname")

    # Handle positioning in the policy table
    if data["before"] or data["after"]
      position = data["before"] ? "before" : "after"
      neighbor = Razor::Data::Policy[:name => data.delete(position)["name"]]
    end

    # Create the policy
    policy = Razor::Data::Policy.new(data).save
    tags.each { |t| policy.add_tag(t) }
    position and policy.move(position, neighbor)
    policy.save

    return policy
  end

  validate :move_policy do
    authz '%{name}'
    attr   'name', type: String, required: true, references: Razor::Data::Policy

    require_one_of 'before', 'after'

    object 'before', exclude: 'after' do
      attr 'name', type: String, required: true, references: Razor::Data::Policy
    end

    object 'after', exclude: 'before' do
      attr 'name', type: String, required: true, references: Razor::Data::Policy
    end
  end

  command :move_policy do |data|
    policy = Razor::Data::Policy[:name => data['name']]
    position = data["before"] ? "before" : "after"
    name = data[position]["name"]
    neighbor = Razor::Data::Policy[:name => name]

    policy.move(position, neighbor)
    policy.save

    policy
  end

  def toggle_policy_enabled(data, enabled, verb)
    data['name'] or error 400,
      :error => _("Supply 'name' to indicate which policy to %{verb}") % {verb: verb}
    policy = Razor::Data::Policy[:name => data['name']] or error 404,
      :error => _("Policy %{name} does not exist") % {name: data['name']}
    policy.enabled = enabled
    policy.save

    # @todo danielp 2014-02-27: I don't think this is going to work out for
    # translation at all, and needs to be replaced by multiple,
    # explicit messages.
    {:result => _("Policy %{name} %{verb}d") % {name: policy.name, verb: verb}}
  end

  command :enable_policy do |data|
    check_permissions! "commands:enable-policy:#{data['name']}"
    toggle_policy_enabled(data, true, 'enable')
  end

  command :disable_policy do |data|
    check_permissions! "commands:disable-policy:#{data['name']}"
    toggle_policy_enabled(data, false, 'disable')
  end

  command :add_policy_tag do |data|
    data['name'] or error 400,
      :error => _("Supply policy name to which the tag is to be added")
    data['tag'] or error 400,
      :error => _("Supply the name of the tag you which to add")

    policy = Razor::Data::Policy[:name => data['name']] or error 404,
      :error => _("Policy %{name} does not exist") % {name: name}
    tag = Razor::Data::Tag.find_or_create_with_rule(
        { 'name' => data['tag'], 'rule' => data['rule'] }
      ) or error 404,
      :error => _("Tag %{name} does not exist and no rule to create it supplied.") % {name: data['tag']}

    unless policy.tags.include?(tag)
      policy.add_tag(tag)
      policy
    else
      action = _("Tag %{tag} already on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end

  command :remove_policy_tag do |data|
    data['name'] or error 400,
      :error => _("Supply policy name to which the tag is to be removed")
    data['tag'] or error 400,
      :error => _("Supply the name of the tag you which to remove")

    policy = Razor::Data::Policy[:name => data['name']] or error 404,
      :error => _("Policy %{name} does not exist") % {name: data['name']}
    tag = Razor::Data::Tag[:name => data['tag']]

    if tag
      if policy.tags.include?(tag)
        policy.remove_tag(tag)
        policy
      else
        action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
        { :result => action }
      end
    else
      action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end

  command :modify_policy_max_count do |data|
    data['name'] or error 400,
      :error => _("Supply the name of the policy to modify")

    policy = Razor::Data::Policy[:name => data['name']] or error 404,
      :error => _("Policy %{name} does not exist") % {name: data['name']}

    data.key?('max-count') or error 400,
      :error => _("Supply a new max-count for the policy")

    max_count_s = data['max-count']
    if max_count_s.nil?
      max_count = nil
      bound = "unbounded"
    else
      max_count = max_count_s.to_i
      max_count.to_s == max_count_s.to_s or
        error 400, :error => _("New max-count '%{raw}' is not a valid integer") % {raw: max_count_s}
      bound = max_count_s
      node_count = policy.nodes.count
      node_count <= max_count or
        error 400, :error => n_(
        "There is currently %{node_count} node bound to this policy. Cannot lower max-count to %{max_count}",
        "There are currently %{node_count} nodes bound to this policy. Cannot lower max-count to %{max_count}",
        node_count) % {node_count: node_count, max_count: max_count}
    end
    policy.max_count = max_count
    policy.save
    { :result => _("Changed max-count for policy %{name} to %{count}") % {name: policy.name, count: bound} }
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

  get '/api/collections/tasks/:name' do
    begin
      task = Razor::Task.find(params[:name])
    rescue Razor::TaskNotFoundError => e
      error 404, :error => _("Task %{name} does not exist") % {name: params[:name]},
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

  get '/api/collections/nodes' do
    collection_view Razor::Data::Node.search(params), 'nodes'
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
    {
      "spec" => spec_url("collections", "nodes", "log"),
      "items" => node.log
    }.to_json
  end

  # @todo lutter 2013-08-18: advertise this in the entrypoint; it's neither
  # a command not a collection.
  get '/api/microkernel/bootstrap' do
    params["nic_max"].nil? or params["nic_max"] =~ /\A[1-9][0-9]*\Z/ or
      error 400,
        :error => _("The nic_max parameter must be an integer not starting with 0")

    # How many NICs ipxe should probe for DHCP
    @nic_max = params["nic_max"].nil? ? 4 : params["nic_max"].to_i

    @task = Razor::Task.mk_task

    render_template("bootstrap")
  end
end
