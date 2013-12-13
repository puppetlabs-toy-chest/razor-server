require_relative '../spec_helper'
require_relative '../../app'

describe "/svc/nodeid" do
  include Rack::Test::Methods

  let :app do
    Razor::App
  end

  let :node do
    Fabricate(:node)
  end

  before :each do
    authorize 'fred', 'dead'
  end

  it "should 400 if no parameters are passed" do
    get '/svc/nodeid'
    last_response.status.should == 400
  end

  it "should return the node ID given the mac address only" do
    get "/svc/nodeid?net0=#{node.hw_hash["mac"].first}"
    last_response.status.should == 200
    last_response.json.should == { 'id' => node.id }
  end
end
