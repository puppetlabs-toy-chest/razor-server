# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::ReinstallNode do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  let(:node) { Fabricate(:node) }
  let(:command_hash) { { 'name' => node.name } }

  before :each do
    authorize 'fred', 'dead'
  end

  def reinstall_node(name)
    command 'reinstall-node', { "name" => name }
  end

  context "/api/commands/reinstall-node" do
    before :each do
      header 'content-type', 'application/json'
    end

    it_behaves_like "a command"

    it "should reinstall a bound node" do
      node = Fabricate(:bound_node)
      reinstall_node(node.name)

      last_response.status.should == 202
      last_response.json['result'].should =~ /node unbound/
      node.reload
      node.policy.should be_nil
      node.installed.should be_nil
      node.installed_at.should be_nil
    end

    it "should reinstall an installed node" do
      node = Fabricate(:bound_node,
                       :installed => 'some_thing',
                       :installed_at => DateTime.now)
      reinstall_node(node.name)

      last_response.status.should == 202
      last_response.json['result'].should =~ /installed flag cleared/
      node.reload
      node.policy.should be_nil
      node.installed.should be_nil
      node.installed_at.should be_nil
    end

    it "should succeed for an unbound node" do
      node = Fabricate(:node)
      reinstall_node(node.name)

      last_response.status.should == 202
      last_response.json['result'].should =~ /neither bound nor installed/
    end

    it "should return 404 for a nonexistent node" do
      reinstall_node("not really an existing node")
      last_response.status.should == 404
      last_response.json['error'].should ==
        "name must be the name of an existing node, but is 'not really an existing node'"
    end
  end
end
