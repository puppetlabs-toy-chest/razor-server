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
      halt [406, {"error" => "only application/json content is available"}.to_json]
  end

  #
  # Server/node API
  #
  helpers do
    def json_body
      if request.content_type =~ %r'application/json'i
        return JSON.parse(request.body.read)
      else
        halt 415, {"error" => "only application/json is accepted here"}.to_json
      end
    rescue => e
      halt 415, {"error" => "unable to parse JSON", "detail" => e.to_s}.to_json
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
      # FIXME: Needs to point to the root directory of the image on the
      # image server.
      # FIXME: Figure out a way to not special-case MK boots everywhere
      #        Try to set up a MK policy and bind nodes to it
      if @image
        "http://images.example.org/#{@image.name}#{path}"
      else
        "http://images.example.org/microkernel#{path}"
      end
    end

    def config
      @config ||= Razor::Util::TemplateConfig.new
    end
  end

  # Client API helpers
  helpers Razor::View

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
    @image = @node.policy.image if @node.policy

    template = @installer.boot_template(@node)

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

  # Command handling and query API: this provides navigation data to allow
  # clients to discover which URL namespace content is available, and access
  # the query and command operations they desire.
  #
  # @todo danielp 2013-06-26: this should be some sort of discovery, not a
  # hand-coded list, but ... it will do, for now.
  get '/api' do
    {
      "commands" => [
        # `rel` is the relationship; by the standard, this is the closest we
        # can get to a conformant identifier for a custom relationship type,
        # and since we expect to consume one per command to avoid clients just
        # knowing the URL, we get this nastiness.  At least we can turn it
        # into something useful by putting documentation about how to use the
        # command or query interface behind it, I guess. --daniel 2013-06-26
        #
        # @todo danielp 2013-06-26: we should actually link to the canonical
        # puppetlabs.com URL for the spec in production, not to something
        # internal to this deployment -- since we expect client applications
        # to use a case-folded match on the URL to identify their
        # desired command.
        {"rel" => url('/spec/create_new_image'), "url" => url('/api/commands/create_new_image')},
        {"rel" => url('/spec/create_installer'), "url" => url('/api/commands/create_installer')},
        {"rel" => url('/spec/create_tag'), "url" => url('/api/commands/create_tag')}
      ],
      "collections" => [
        {"id"=> "tags", "rel" => url('/spec/list_tags'), "url" => url('/api/collections/tags')},
        {"id" => "policies", "rel" => url('/spec/list_policies'), "url" => url('/api/collections/policies')},
      ]
    }.to_json
  end

  post '/api/commands/create_new_image' do
    data = json_body
    data.is_a?(Hash) or halt [415, "body must be a JSON object"]

    # Create our shiny new image.  This will implicitly, thanks to saving
    # changes, trigger our loading saga to begin.  (Which takes place in the
    # same transactional context, ensuring we don't send a message to our
    # background workers without also committing this data to our database.)
    image = begin
              Razor::Data::Image.new(data).save.freeze
            rescue => e
              halt 400, e.to_s
            end

    # Finally, return the state (started, not complete) and the URL for the
    # final image to our poor caller, so they can watch progress happen.
    [202, view_object_reference(image).to_json]
  end

  post '/api/commands/create_installer' do
    data = json_body
    data.is_a?(Hash) or halt [415, "body must be a JSON object"]

    # If boot_seq is not a Hash, the model validation for installers
    # will catch that, and will make saving the installer fail
    if (boot_seq = data["boot_seq"]).is_a?(Hash)
      # JSON serializes integers as strings, undo that
      boot_seq.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
        each { |k| boot_seq[k.to_i] = boot_seq.delete(k) }
    end

    installer = begin
                  Razor::Data::Installer.new(data).save.freeze
                rescue => e
                  halt 400, e.to_s
                end

    [202, view_object_reference(installer).to_json]
  end

  post '/api/commands/create_tag' do
    data = json_body
    data.is_a?(Hash) or halt [415, "body must be a JSON object"]

    tag = begin
            Razor::Data::Tag.find_or_create_with_rule(data)
          rescue => e
            halt 400, e.to_s
          end

    [202, view_object_reference(tag).to_json]
  end

  post '/api/create_policy' do
    data = json_body
    data.is_a?(Hash) or halt [415, "body must be a JSON object"]

    begin
      tags = (data.delete("tags") || []).map do |t|
        Razor::Data::Tag.find_or_create_with_rule(t)
      end

      if data["image"]
        name = data["image"]["name"] or
          halt [400, "The image reference must have a 'name'"]
        data["image"] = Razor::Data::Image[:name => name] or
          halt [400, "Image '#{name}' not found"]
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
    rescue => e
      halt 400, e.to_s
    end

    [202, view_object_reference(policy).to_json]
  end

  #
  # Query/collections API
  #
  get '/api/collections/tags' do
    Razor::Data::Tag.all.map {|t| view_object_reference(t)}.to_json
  end

  get '/api/collections/tags/:name' do
    tag = Razor::Data::Tag[:name => params[:name]] or
      halt 404, "no tag matched id=#{params[:name]}"
    tag_hash(tag).to_json
  end

  get '/api/collections/policies' do
    Razor::Data::Policy.all.map {|p| view_object_reference(p)}.to_json
  end

  get '/api/collections/policies/:name' do
    policy = Razor::Data::Policy[:name => params[:name]] or
      halt 404, "no policy matched id=#{params[:name]}"
    policy_hash(policy).to_json
  end

  # FIXME: Add a query to list all installers

  get '/api/collections/installers/:name' do
    begin
      installer = Razor::Installer.find(params[:name])
    rescue Razor::InstallerNotFoundError => e
      halt [404, e.to_s]
    end
    installer_hash(installer).to_json
  end

  get '/api/collections/images' do
    Razor::Data::Image.all.map { |img| view_object_reference(img)}.to_json
  end

  get '/api/collections/images/:name' do
    image = Razor::Data::Image[:name => params[:name]] or
      halt 404, "no image matched name=#{params[:name]}"
    image_hash(image).to_json
  end
end
