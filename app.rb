require 'sinatra'

require_relative './lib/razor/initialize'
require_relative './lib/razor'

class Razor::App < Sinatra::Base
  configure do
    # FIXME: This turns off template caching alltogether since I am not
    # sure that the caching won't interfere with how we lookup
    # templates. Need to investigate whether this really is an issue, and
    # hopefully can enable template caching (which does not happen in
    # development mode anyway)
    set :reload_templates, true
  end

  before do
    case request.path_info
    # We serve static files from /svc/image and will therefore let that
    # handler determine the most appropriate content type
    when %r'\A/svc/image' then pass

    # We serve JSON Siren from /api and /api/collections
    when %r'\A/api($|/collections)'
      content_type 'application/vnd.siren+json'
      pass

    # Set our content type: like many people, we simply don't negotiate.
    else
    content_type 'application/json'
    end
  end

  before %r'/api($|/)'i do
    # Ensure that we can happily talk application/json with the client.
    # At least this way we tell you when we are going to be mean.
    #
    # This should read `request.accept?(application/json)`, but
    # unfortunately for us, https://github.com/sinatra/sinatra/issues/731
    # --daniel 2013-06-26
    case request.path_info
    when %r'\A/api($|/collections)'
      request.preferred_type('application/vnd.siren+json') or
        halt [406, {"error" => "only application/vnd.siren+json content is available"}.to_json]
    else
      request.preferred_type('application/json') or
        halt [406, {"error" => "only application/json content is available"}.to_json]
    end
  end

  #
  # Server/node API
  #
  helpers do
    def error(status, body = {})
      halt status, body.to_json
    end

    def json_body
      if request.content_type =~ %r'application/json'i
        return JSON.parse(request.body.read)
      else
        error 415, :error => "only application/json is accepted here"
      end
    rescue => e
      error 415, :error => "unable to parse JSON", :details => e.to_s
    end

    def compose_url(*parts)
      escaped = '/' + parts.compact.map{|x|URI::escape(x.to_s)}.join('/')
      url escaped.gsub(%r'//+', '/')
    end

    def file_url(template)
      url "/svc/file/#{@node.id}/#{URI::escape(template)}"
    end

    def log_url(msg, severity=:info)
      q = ::URI::encode_www_form(:msg => msg, :severity => severity)
      url "/svc/log/#{@node.id}?#{q}"
    end

    def store_url(vars)
      q = ::URI::encode_www_form(vars)
      url "/svc/store/#{@node.id}?#{q}"
    end

    def broker_install_url
      # FIXME: figure out how we handle serving the broker install script
      "http://example.org/FILL-IN-BROKER-INSTALL"
    end

    def node_url
      url "/api/nodes/#{@node.id}"
    end

    def image_url(path = "")
      url "/svc/image/#{@image.name}#{path}"
    end

    def config
      @config ||= Razor::Util::TemplateConfig.new
    end

    def underscore_keys(data)
      if data.is_a? Array
        data.map {|x| x.respond_to?(:each) ? underscore_keys(x) : x}
      elsif data.is_a? Hash
        data.keys.each do |key|
          value = data.delete(key)
          value = underscore_keys(value) if value.respond_to? :each
          data[key.tr('-','_')] = value
        end
        data
      end
    end
  end

  # Client API helpers
  helpers Razor::View
  helpers Razor::View::Siren

  # Error handlers for node API
  error Razor::TemplateNotFoundError do
    status 404
  end

  error Razor::Util::ConfigAccessProhibited do
    status 500
  end

  # Convenience for /svc/boot and /svc/file
  def render_template(name)
    locals = { :installer => @installer, :node => @node, :image => @image }
    content_type 'text/plain'
    template, opts = @installer.find_template(name)
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
  post '/svc/checkin' do
    return 400 if request.content_type != 'application/json'
    begin
      json = JSON::parse(request.body.read)
    rescue JSON::ParserError
      return 400
    end
    return 400 unless json['facts'] and json['hw_id']
    Razor::Data::Node.checkin(json).to_json
  end

  get '/svc/boot/:hw_id' do
    @node = Razor::Data::Node.boot(params[:hw_id], params[:dhcp_mac])

    @installer = @node.installer

    if @node.policy
      @image = @node.policy.image
    else
      # @todo lutter 2013-08-19: We have no policy on the node, and will
      # therefore boot into the MK. This is a gigantic hack; all we need is
      # an image with the right name so that the image_url helper generates
      # links to the microkernel directory in the image store.
      #
      # We do not have API support yet to set up MK's, and users therefore
      # have to put the kernel and initrd into the microkernel/ directory
      # in their image store manually for things to work.
      @image = Razor::Data::Image.new(:name => "microkernel",
                    :image_url => "file:///dev/null")
    end
    template = @installer.boot_template(@node)

    @node.log_append(:event => :boot, :installer => @installer.name,
                     :template => template, :image => @image.name)
    @node.save
    render_template(template)
  end

  get '/svc/file/:node_id/:template' do
    @node = Razor::Data::Node[params[:node_id]]
    halt 404 unless @node

    halt 409 unless @node.policy

    @installer = @node.installer
    @image = @node.policy.image

    render_template(params[:template])
  end

  get '/svc/log/:node_id' do
    node = Razor::Data::Node[params[:node_id]]
    halt 404 unless node

    node.log_append(:msg=> params[:msg], :severity => params[:severity])
    node.save
    [204, {}]
  end

  get '/svc/store/:node_id' do
    node = Razor::Data::Node[params[:node_id]]
    halt 404 unless node
    halt 400 unless params[:ip]

    # We only allow setting the ip address for now
    node.ip_address = params[:ip]
    node.log_append(:msg => "received IP address #{node.ip_address}")
    node.save
    [204, {}]
  end

  get '/svc/image/*' do |path|
    root = File.expand_path(Razor.config['image_store_root'])
    fpath = File.join(root, path)
    fpath.start_with?(root) and File.file?(path) or
      [404, { :error => "File #{path} not found" }.to_json ]

    content_type nil
    send_file fpath, :disposition => nil
  end

  # The collections we advertise in the API

  #
  # The main entry point for the public/management API
  #
  get '/api' do

    siren_entity(class_url('api'), nil,
      @@collections["/api"].dup.map {|x| x.merge :href => url(x[:href]) },
      @@actions["/api"] ).to_json
  end


  def self.collection(type, &block)
    @@collections ||= Hash.new {|h,k| h[k]=[]}
    @@actions     ||= Hash.new {|h,k| h[k]=[]}

    @type_pl = type.to_s.pluralize
    @type = type.to_s.singularize

    @path = "/api/collections/#{@type_pl}"
    @class = "Razor::Data::#{@type.classify}".constantize
    instance_exec(&block)
  end

  def self.create(&block)
    @fields = []
    call = instance_exec(&block)

    @@actions[@path] << Razor::View::Siren.action("create",
      "Create #{@type.indefinite_article} #{@type}", @path,
      Razor::View::class_url(@class), @fields || [], "POST" )

    handler = lambda do
      data = json_body
      data.is_a?(Hash) or error 415, :error => "body must be a JSON object"
      data = underscore_keys(data)
      begin
        result = instance_exec(data, &call)
      rescue => e
        error 400, :details => e.to_s
      end
      result = view_reference_object(result, spec_url("self")) unless result.is_a?(Hash)
      [202, result.to_json]
    end

    post @path, &handler
    post "/api/commands/create-#{@type}", &handler
  end

  def self.fields(fields)
    @fields = fields
  end

  def self.retrieve_all(&block)
    @@collections["/api"] << Razor::View::Siren.object_ref(
      [Razor::View::class_url("collection"), Razor::View::class_url(@class)],
      Razor::View::spec_url("collections", @type_pl),
      "/api/collections/#{@type_pl}", @type_pl )

    klass = @class; path = @path
    get @path do
      view_reference_collection(klass, instance_exec(&block), nil,
        @@actions[path].dup.map {|x| x.merge :href => url(x[:href]) }).to_json
    end
  end

  def self.retrieve_one(&block)
    path = @path + "/:name"
    get path do
      actions = @@actions[path].map {|x| x.merge :href=>url(x[:href]) }
      view_object_hash(instance_exec(&block), actions.any? ? actions : nil).to_json
    end
  end

  def self.delete_one(&block)
    delete @path+"/:name" do
      [202, { :result => instance_exec(&block) }.to_json]
    end

    post "/api/commands/delete-#{@type}" do
      data = json_body
      data.is_a?(Hash) or error 415, :error => "body must be a JSON object"
      params[:name] = data["name"]
      [202, { :result => instance_exec(&block) }.to_json]
    end

    @@actions[@path+"/:name"] << Razor::View::Siren.action("delete", "Delete #{@type}",
      @path, Razor::View::class_url(@class), [], "DELETE" )
  end

  collection :images do
create do
  fields [ Razor::View::Siren::action_field('name'),
    Razor::View::Siren::action_field('image-url') ]

  lambda do |data|
    # Create our shiny new image.  This will implicitly, thanks to saving
    # changes, trigger our loading saga to begin.  (Which takes place in the
    # same transactional context, ensuring we don't send a message to our
    # background workers without also committing this data to our database.)
    image = Razor::Data::Image.new(data).save.freeze

    # Finally, return the state (started, not complete) and the URL for the
    # final image to our poor caller, so they can watch progress happen.
    image
  end
end

  delete_one do
    params[:name] or error 400,
      :error => "Supply 'name' to indicate which image to delete"
    if image = Razor::Data::Image[:name => params[:name]]
      image.destroy
      "image destroyed"
    else
      "no changes; image #{params[:name]} does not exist"
    end
  end

    retrieve_all do
      Razor::Data::Image.all
    end

    retrieve_one do
      Razor::Data::Image[:name => params[:name]] or
        error 404, :error => "no image matched name=#{params[:name]}"
    end
  end

  collection :installers do
create do
  fields [ Razor::View::Siren::action_field('name'),
    Razor::View::Siren::action_field('os'),
    Razor::View::Siren::action_field('os-version'),
    Razor::View::Siren::action_field('description'),
    Razor::View::Siren::action_field('boot-seq'),
    Razor::View::Siren::action_field('templates'),
  ]

  lambda do |data|
    # If boot_seq is not a Hash, the model validation for installers
    # will catch that, and will make saving the installer fail
    if (boot_seq = data["boot_seq"]).is_a?(Hash)
      # JSON serializes integers as strings, undo that
      boot_seq.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
        each { |k| boot_seq[k.to_i] = boot_seq.delete(k) }
    end

    Razor::Data::Installer.new(data).save.freeze
  end
end

# FIXME: Add a query to list all installers

    retrieve_one do
      begin
        installer = Razor::Installer.find(params[:name])
      rescue Razor::InstallerNotFoundError => e
        error 404, :error => "Installer #{params[:name]} does not exist",
          :details => e.to_s
      end
    end
  end

  collection :tags do
create do
  fields [ Razor::View::Siren::action_field('name'),
    Razor::View::Siren::action_field('rule'),
  ]

  lambda do |data|
    Razor::Data::Tag.find_or_create_with_rule(data)
  end
end

    retrieve_all do
      Razor::Data::Tag.all
    end

    retrieve_one do
      Razor::Data::Tag[:name => params[:name]] or
        error 404, :error => "no tag matched id=#{params[:name]}"
    end
  end

  collection :brokers do
create do
  fields [ Razor::View::Siren::action_field('name'),
    Razor::View::Siren::action_field('configuration'),
    Razor::View::Siren::action_field('broker-type'),
  ]

  lambda do |data|
    if type = data["broker_type"]
      begin
        data["broker_type"] = Razor::BrokerType.find(type)
      rescue Razor::BrokerTypeNotFoundError
        halt [400, "Broker type '#{type}' not found"]
      rescue => e
        halt 400, e.to_s
      end
    end
    Razor::Data::Broker.new(data).save
  end
end

    retrieve_all do
      Razor::Data::Broker.all
    end

    retrieve_one do
      Razor::Data::Broker[:name => params[:name]] or
        halt 404, "no broker matched id=#{params[:name]}"
    end
  end

  collection :policies do
create do
  fields [ Razor::View::Siren::action_field('name'),
    Razor::View::Siren::action_field('image'),
    Razor::View::Siren::action_field('installer'),
    Razor::View::Siren::action_field('hostname'),
    Razor::View::Siren::action_field('root-password'),
    Razor::View::Siren::action_field('enabled','checkbox'),
    Razor::View::Siren::action_field('line-number'),
    Razor::View::Siren::action_field('broker'),
  ]

  lambda do |data|
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find_or_create_with_rule(t)
    end

    if data["image"]
      name = data["image"]["name"] or
        error 400, :error => "The image reference must have a 'name'"
      data["image"] = Razor::Data::Image[:name => name] or
        error 400, :error => "Image '#{name}' not found"
    end

    if data["broker"]
      name = data["broker"]["name"] or
        halt [400, "The broker reference must have a 'name'"]
      data["broker"] = Razor::Data::Broker[:name => name] or
        halt [400, "Broker '#{name}' not found"]
    end

    if data["installer"]
      data["installer_name"] = data.delete("installer")["name"]
    end
    data["hostname_pattern"] = data.delete("hostname")

    policy = Razor::Data::Policy.new(data).save
    tags.each { |t| policy.add_tag(t) }
    policy.save

    policy
  end
end

    retrieve_all do
      Razor::Data::Policy.all
    end

    retrieve_one do
      Razor::Data::Policy[:name => params[:name]] or
        error 404, :error => "no policy matched id=#{params[:name]}"
    end
  end

  collection :nodes do
    retrieve_all do
      Razor::Data::Node.all
    end

    retrieve_one do
      Razor::Data::Node[:hw_id => params[:name]] or
        error 404, :error => "no node matched hw_id=#{params[:name]}"
    end
  end

  get '/api/collections/nodes/:hw_id/log' do
    # @todo lutter 2013-08-20: There are no tests for this handler
    # @todo lutter 2013-08-20: Do we need to send the log through a view ?
    node = Razor::Data::Node[:hw_id => params[:hw_id]] or
      error 404, :error => "no node matched hw_id=#{params[:hw_id]}"
    node.log.to_json
  end

  # @todo lutter 2013-08-18: advertise this in the entrypoint; it's neither
  # a command not a collection.
  get '/api/microkernel/bootstrap' do
    params["nic_max"].nil? or params["nic_max"] =~ /\A[1-9][0-9]*\Z/ or
      error 400,
        :error => "The nic_max parameter must be an integer not starting with 0"

    # How many NICs ipxe should probe for DHCP
    @nic_max = params["nic_max"].to_i || 4

    @installer = Razor::Installer.mk_installer

    render_template("bootstrap")
  end
end
