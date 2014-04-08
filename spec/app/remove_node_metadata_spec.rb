# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "remove node metadata command" do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:node) do
    Fabricate(:node)
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def remove_metadata(data)
    command 'remove-node-metadata', data
  end

  it "should require a node" do
    data = { 'key' => 'k1', 'value' => 'v1' }
    remove_metadata(data)
    last_response.status.should == 422
    JSON.parse(last_response.body)["error"].should ==
      "node is a required attribute, but it is not present"
  end

  it "should require a key or all" do
    data = { 'node' => "node#{node.id}"}
    remove_metadata(data)
    last_response.status.should == 422
    JSON.parse(last_response.body)["error"].should =~
      /the command requires one out of the all, key attributes to be supplied/
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
