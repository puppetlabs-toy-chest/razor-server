require 'sinatra'

require_relative './lib/razor/initialize'
require_relative './lib/razor'

class Razor::App < Sinatra::Base

  before do
    content_type 'application/json'
  end

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
    content_type "text/plain"
    node = Razor::Data::Node.lookup(params[:hw_id])
    # look up node
    # respond with next templated response
    Razor::PolicyTemplate::Microkernel.new.ipxe
  end

  get '/svc/log/:node_id' do
    node = Razor::Data::Node[params[:node_id]]
    halt 404 unless node

    node.log_append(:msg=> params[:msg], :severity => params[:severity])
    node.save
    [204, {}]
  end

  # General purpose API
  get '/api' do
    { :missing => "global entry point" }.to_json
  end
end
