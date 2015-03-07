# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::RegisterNode do
  include Razor::Test::Commands

  let :app do Razor::App end
  let :node do Fabricate(:node) end
  let :command_hash do
    {
        'hw_info' => node_hw_hash_to_hw_info(node.hw_hash),
        'installed' => true
    }
  end

  before :each do
    authorize 'fred', 'dead'
    header    'content-type', 'application/json'
  end

  def register_node(params)
    command 'register-node', params
  end

  # Build something suitable for sending in, from the hardware info stored in
  # the node; sadly the two are in pretty radically different formats.
  def node_hw_hash_to_hw_info(hw_hash)
      hw_hash.inject({}) do |hash, (k, v)|
      if k == 'mac'
        v.each_with_index {|v,n| hash["net#{n}"] = v }
      else
        hash[k] = v
      end
      hash
    end
  end

  it_behaves_like "a command"

  it "should create a new node based on the input data" do
    register_node 'installed' => true, 'hw_info' => {'net0' => '00:0c:29:08:06:e0'}
    last_response.status.should == 202
    data = last_response.json
    data['name'].should =~ /^node\d+$/

    Razor::Data::Node[name: data['name']].should be
  end

  it "should return an existing node matching the input data" do
    node = Fabricate(:node)
    register_node 'installed' => true, 'hw_info' => node_hw_hash_to_hw_info(node.hw_hash)

    last_response.status.should == 202
    data = last_response.json

    Razor::Data::Node[name: data['name']].should be
    data['name'].should == node.name
  end

  it "should set installed to true if created with install set to true" do
    register_node 'installed' => true, 'hw_info' => {'net0' => '00:0c:29:08:06:e0'}
    last_response.status.should == 202
    data = last_response.json
    data['name'].should =~ /^node\d+$/

    Razor::Data::Node[name: data['name']].installed.should be_true
  end

  it "should set installed to false if created with install set to false" do
    register_node 'installed' => false, 'hw_info' => {'net0' => '00:0c:29:08:06:e0'}
    last_response.status.should == 202
    data = last_response.json
    data['name'].should =~ /^node\d+$/

    Razor::Data::Node[name: data['name']].installed.should be_false
  end

  it "should set installed to true if existing node" do
    node = Fabricate(:node, installed: false)
    register_node 'installed' => true, 'hw_info' => node_hw_hash_to_hw_info(node.hw_hash)
    last_response.status.should == 202
    node.reload.installed.should be_true
  end

  it "should set installed to false if existing node" do
    node = Fabricate(:node, installed: true)
    register_node 'installed' => false, 'hw_info' => node_hw_hash_to_hw_info(node.hw_hash)
    last_response.status.should == 202
    node.reload.installed.should be_false
  end

  it "should fail if hw_info is empty" do
    register_node 'installed' => true, 'hw_info' => {}
    last_response.json['error'].should ==
      'hw_info must have at least 1 entries, only contains 0'
    last_response.status.should == 422
  end

  it "should accept unlimited (well, 1,000) MAC addresses" do
    hw_info = (0..999).inject({}) do |hash, n|
      hash["net#{n}"] = "00:0c:29:5e:%02x:%02x" % [n/256,n%256]
      hash
    end

    register_node 'installed' => true, 'hw_info' => hw_info
    last_response.status.should == 202
  end

  it "should accept serial numbers" do
    register_node 'installed' => true, 'hw_info' => {'serial' => '00000'}
    last_response.status.should == 202
  end

  it "should accept asset tags" do
    register_node 'installed' => true, 'hw_info' => {'asset' => '00000'}
    last_response.status.should == 202
  end

  it "should accept UUID" do
    register_node 'installed' => true, 'hw_info' => {'uuid' => '00000'}
    last_response.status.should == 202
  end

  it "should work with installed true" do
    register_node 'installed' => true, 'hw_info' => {'net0' => '00:0c:29:b0:96:df'}
    last_response.status.should == 202
  end

  it "Should work with installed false" do
    register_node 'installed' => false, 'hw_info' => {'net0' => '00:0c:29:b0:96:df'}
    last_response.status.should == 202
  end

  it "should fail if installed is a string true" do
    register_node 'installed' => "true", 'hw_info' => {'net0' => '00:0c:29:b0:96:df'}
    last_response.json['error'].should ==
      'installed should be a boolean, but was actually a string'
    last_response.status.should == 422
  end

  it "should fail if installed is a string false" do
    register_node 'installed' => "false", 'hw_info' => {'net0' => '00:0c:29:b0:96:df'}
    last_response.json['error'].should ==
      'installed should be a boolean, but was actually a string'
    last_response.status.should == 422
  end

  it "should conform the old 'hw-info' syntax" do
    register_node 'installed' => false, 'hw-info' => {'net0' => '00:0c:29:b0:96:df'}
    last_response.status.should == 202
  end
end
