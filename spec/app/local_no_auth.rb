# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

require 'json-schema'

describe "local requests without authentication" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    header 'content-type', 'application/json'
  end

  context "/api without auth" do
    it "no auth for local requests if auth.allow_localhost is set" do
      Razor.config['auth.allow_localhost'] = true
      get '/api/collections/repos', {}, {'REMOTE_ADDR' => '127.0.0.1'}
      last_response.status.should == 200

      post '/api/commands/create-broker', {'name' => 'abc', 'broker-type' => 'puppet'}.to_json
      last_response.status.should == 202
    end
   
    it "auth for non local requests if auth.allow_localhost is set" do
      Razor.config['auth.allow_localhost'] = true
      get '/api/collections/repos', {}, {'REMOTE_ADDR' => '172.17.10.10'}

      last_response.status.should == 401
    end
 
    it "auth for local requests if auth.allow_localhost is not set" do
      Razor.config['auth.allow_localhost'] = false
      get '/api/collections/repos', {}, {'REMOTE_ADDR' => '127.0.0.1'}

      last_response.status.should == 401
    end

    it "auth for non local requests if auth.allow_localhost is not set" do
      Razor.config['auth.allow_localhost'] = false
      get '/api/collections/repos', {}, {'REMOTE_ADDR' => '172.17.10.10'}

      last_response.status.should == 401
    end
  end
end
