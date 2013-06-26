require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  context "/ - API navigation index" do
    %w[text/plain text/html text/* application/js].each do |type|
      it "should reject #{type.inspect} content requests" do
        header 'Accept', type
        get '/api'
        last_response.status.should == 406
      end
    end

    it "should return JSON content" do
      get '/api'
      last_response.content_type.should =~ /application\/json/i
    end

    it "should match the shape of our command handler" do
      get '/api'
      data = last_response.json
      data.keys.should =~ %w[commands]
      data["commands"].all? {|x| x.keys.should =~ %w[rel url]}
    end
  end
end
