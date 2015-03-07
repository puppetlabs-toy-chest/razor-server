# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::SetNodeHWInfo do
  include Razor::Test::Commands

  let :app do Razor::App end
  let :node do Fabricate(:node) end
  let :command_hash do
    {
        'node' => node.name,
        'hw_info' => node_hw_hash_to_hw_info(node.hw_hash)
    }
  end

  before :each do
    authorize 'fred', 'dead'
    header    'content-type', 'application/json'
  end

  def set_node_hw_info
    command 'set-node-hw-info', command_hash
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

  it "should fail if the node does not exist" do
    command_hash['node'] = 'freddy'
    set_node_hw_info
    last_response.json['error'].
      should == "node must be the name of an existing node, but is 'freddy'"
     last_response.status.should == 404
  end

  it "should fail if the hw_info does not contain any match keys" do
    Razor.config['match_nodes_on'] = ['mac'] # default, but be safe!
    command_hash['hw_info'] = {serial: '1234'}
    set_node_hw_info
    last_response.json['error'].
      should == "hw_info must contain at least one of the match keys: mac"
     last_response.status.should == 422
  end

  it "should succeed but not change the node hw_info if it is the same" do
    command_hash['hw_info'] = node_hw_hash_to_hw_info(node.hw_hash)
    set_node_hw_info
    last_response.status.should == 202
    Razor::Data::Node[id: node.id].hw_hash.should == node.hw_hash
  end

  it "should update the node hw_info if it is different" do
    before = node.hw_hash
    before.should_not == {'serial' => '1234'}

    command_hash['hw_info'] = {serial: '1234'}
    set_node_hw_info
    last_response.status.should == 202

    Razor::Data::Node[id: node.id].hw_hash.should == {'serial' => '1234'}
    Razor::Data::Node[id: node.id].should_not == before
  end

  it "should conform the old 'hw-info' syntax" do
    command_hash['hw-info'] = command_hash.delete('hw_info')
    set_node_hw_info
    last_response.status.should == 202
  end
end
