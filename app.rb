require 'sinatra'

require_relative './lib/razor/initialize'
require_relative './lib/razor'

class Razor::App < Sinatra::Base

  before do
    content_type 'application/json'
  end

  # API for MK
  post '/svc/checkin/:id' do
    # deserialize body, pass to backend
  end

  get '/svc/boot/:mac_id' do
    content_type "text/plain"
    node = Razor::Models::Node.lookup(params[:mac_id])
    # look up node
    # respond with next templated response
    Razor::PolicyTemplate::Microkernel.new.ipxe
  end

  # General purpose API
  get '/api' do
    { :missing => "global entry point" }.to_json
  end
end
