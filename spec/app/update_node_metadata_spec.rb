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
    data = { 'node' => "node#{node.id}", 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /no_replace should be a boolean, but was actually a string/
  end

  it "should conform no_replace" do
    data = { 'node' => "node#{node.id}", 'key' => 'k1', 'value' => 'v1', 'no_replace' => 'not true' }
    update_metadata(data)
    last_response.status.should == 422
    last_response.json["error"].should =~ /no_replace should be a boolean, but was actually a string/
  end

  #Defer to the modify-node-metadata tests for the verification of the
  #actual work.
end
