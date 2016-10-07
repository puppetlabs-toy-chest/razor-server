# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdateNodeMetadata do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:node) do
    Fabricate(:node)
  end
  let(:command_hash) do
    {
        'node' => node.name,
        'value' => 'v1',
        'key' => 'k1',
        'no_replace' => 'true'
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_metadata(data)
    command 'update-node-metadata', data
  end

  it_behaves_like "a command"

  it "should require no_replace to equal true" do
    data = { 'node' => node.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /no_replace should be a boolean, but was actually a string/
  end

  it "should not update the value if no_replace is true and the value exists" do
    node.metadata = {'k1' => 'old-value'}
    node.save
    data = { 'node' => node.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => true }
    update_metadata(data)
    last_response.status.should == 409
    node.reload.metadata.should == {'k1' => 'old-value'}
    last_response.json['error'].should == 'no_replace supplied and key is present'
  end

  it "should conform no_replace" do
    node.metadata = {'k1' => 'old-value'}
    node.save
    data = { 'node' => node.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'true' }
    update_metadata(data)
    last_response.status.should == 409
    node.reload.metadata.should == {'k1' => 'old-value'}
    last_response.json['error'].should == 'no_replace supplied and key is present'
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
