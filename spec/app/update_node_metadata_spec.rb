# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "update node metadata command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  let(:node) do
    Fabricate(:node)
  end

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
    last_response.status.should == 422
    last_response.json["error"].should =~ /required attribute node is missing/
  end

  it "should require a key" do
    data = { 'node' => "node#{node.id}", 'value' => 'v1' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /one of all, key must be supplied/
  end

  it "should require a value" do
    data = { 'node' => "node#{node.id}", 'key' => 'k1' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /required attribute value is missing/
  end

  it "should require no_replace to equal true" do
    data = { 'node' => "node#{node.id}", 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /'no_replace' must be boolean true or string 'true'/
  end

  it "should require all to equal true" do
    data = { 'node' => "node#{node.id}", 'value' => 'v1', 'all' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /'all' must be boolean true or string 'true'/
  end

  it "should succeed with 'all' and 'no_replace'" do
    data = { 'node' => "node#{node.id}", 'value' => 'v1', 'all' => 'true', 'no_replace' => 'true' }
    update_metadata(data)
    last_response.status.should == 202
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
