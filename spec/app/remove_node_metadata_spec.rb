require_relative '../spec_helper'
require_relative '../../app'

describe "remove node metadata command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def remove_metadata(data)
    post '/api/commands/remove-node-metadata', data.to_json
  end

  it "should require a node" do
    data = { 'key' => 'k1', 'value' => 'v1' }
    remove_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply node/
  end

  it "should require a key or all" do
    data = { 'node' => 'node1' }
    remove_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply key or set all to true/
  end

  it "should require all to equal true" do
    data = { 'node' => 'node1', 'all' => 'not true' }
    remove_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply key or set all to true/
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
