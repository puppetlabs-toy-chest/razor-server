# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdatePolicyNodeMetadata do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:policy) { Fabricate(:policy) }

  let(:command_hash) do
    {
        'policy' => policy.name,
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
    command 'update-policy-node-metadata', data
  end

  it_behaves_like "a command"

  it "should require no_replace to equal true" do
    data = { 'policy' => policy.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /no_replace should be a boolean, but was actually a string/
  end

  it "should conform no_replace" do
    policy.node_metadata = {'k1' => 'old-value'}
    policy.save
    data = { 'policy' => policy.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'true' }
    update_metadata(data)
    last_response.status.should == 409
  end

  it "should set a policy's node_metadata" do
    policy = Fabricate(:policy)
    data = { 'policy' => policy.name, 'key' => 'k1', 'value' => 'v1' }
    update_metadata(data)
    last_response.status.should == 202
    policy.reload
    policy.node_metadata.should == {'k1' => 'v1'}
  end

  it "should not update the value if no_replace is true and the value exists" do
    policy.node_metadata = {'k1' => 'old-value'}
    policy.save
    data = { 'policy' => policy.name, 'key' => 'k1', 'value' => 'v1', 'no_replace' => true }
    update_metadata(data)
    last_response.status.should == 409
    policy.reload.node_metadata.should == {'k1' => 'old-value'}
    last_response.json['error'].should == 'no_replace supplied and key is present'
  end

  it "should update a policy's node_metadata" do
    update_data = { 'policy' => "#{policy.name}", 'key' => 'k1', 'value' => 'v2' }
    update_metadata(update_data)
    last_response.status.should == 202
    policy.reload
    policy.node_metadata.should == {'k1' => 'v2'}
  end
end
