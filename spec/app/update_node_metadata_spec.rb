require_relative '../spec_helper'
require_relative '../../app'

describe "update node metadata command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_metadata(data)
    post '/api/commands/update-node-metadata', data.to_json
  end

  it "should require a node" do
    data = { 'key' => 'k1', 'value' => 'v1' }
    update_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply node/
  end

  it "should require a key" do
    data = { 'node' => 'node1', 'value' => 'v1' }
    update_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply key/
  end

  it "should require a value" do
    data = { 'node' => 'node1', 'key' => 'k1' }
    update_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply value/
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
