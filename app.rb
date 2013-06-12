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
    Razor::Models::Node.checkin(params[:hw_id], json).to_json
  end

  get '/svc/boot/:hw_id' do
    content_type "text/plain"
    node = Razor::Models::Node.lookup(params[:hw_id])
    # look up node
    # respond with next templated response
    Razor::PolicyTemplate::Microkernel.new.ipxe
  end

  # General purpose API
  get '/api' do
    { :missing => "global entry point" }.to_json
  end
end
