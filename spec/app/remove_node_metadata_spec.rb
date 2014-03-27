# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "remove node metadata command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  let(:node) do
    Fabricate(:node)
  end

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
    last_response.status.should == 422
    JSON.parse(last_response.body)["error"].should =~ /required attribute node is missing/
  end

  it "should require a key or all" do
    data = { 'node' => "node#{node.id}"}
    remove_metadata(data)
    last_response.status.should == 422
    JSON.parse(last_response.body)["error"].should =~ /one of all, key must be supplied/
  end

  it "should require all to equal true" do
    data = { 'node' => "node#{node.id}", 'all' => 'not true' }
    remove_metadata(data)
    last_response.status.should == 422
    JSON.parse(last_response.body)["error"].should =~ /invalid value for attribute 'all'/
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
