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
    content_type 'application/json'
  end

  #
  # Server/node API
  #
  helpers do
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

  # Error handlers for node API
  error Razor::TemplateNotFoundError do
    status 404
  end

  error Razor::Util::ConfigAccessProhibited do
    status 500
  end

  # Convenience for /svc/boot and /svc/file
  def render_template(template)
    locals = { :installer => @installer, :node => @node, :image => @image }
    content_type 'text/plain'
    erb template.to_sym, :locals => locals,
        :views => @installer.view_path(template),
        :layout => false
  end

  # FIXME: We report various errors without a body. We need to include both
  # human-readable error indications and some sort of machine-usable error
  # messages, possibly along the lines of
  # http://www.mnot.net/blog/2013/05/15/http_problem

  # API for MK
  post '/svc/checkin/:hw_id' do
    return 400 if request.content_type != 'application/json'
    begin
      json = JSON::parse(request.body.read)
    rescue JSON::ParserError
      return 400
    end
    return 400 unless json['facts']
    Razor::Data::Node.checkin(params[:hw_id], json).to_json
  end

  get '/svc/boot/:hw_id' do
    @node = Razor::Data::Node.boot(params[:hw_id])

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

  # General purpose API
  get '/api' do
    { :missing => "global entry point" }.to_json
  end
end
