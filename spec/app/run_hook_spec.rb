# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::RunHook do
  include Razor::Test::Commands

  before :each do
    use_hook_fixtures
  end

  let(:app) { Razor::App }
  let(:hook) { Fabricate(:counter_hook)}
  let(:node) { Fabricate(:node)}
  let(:command_hash) do
    {
        "name" => hook.name,
        "event" => 'node-booted',
        "node" => node.name
    }
  end
  before :each do
    authorize 'fred', 'dead'
  end

  def run_hook(hash = command_hash)
    command 'run-hook', hash
  end

  it_behaves_like "a command"

  before :each do
    header 'content-type', 'application/json'
  end

  it "should return the resulting event" do
    hook.configuration[command_hash['event']].should == 0
    run_hook
    last_response.status.should == 202
    last_response.json['spec'].should =~ /events/
    event_name = last_response.json['name']
    event = Razor::Data::Event[id: event_name]
    event.node_id.should == node.id
    event.hook_id.should == hook.id
    event.entry['event'].should == command_hash['event']
    event.entry['exit_status'].should == 0
    event.entry['actions'].should == <<-EOT.strip
updating hook configuration: {\"update\"=>{\"#{command_hash['event']}\"=>1}} and updating node metadata: {\"update\"=>{\"last_hook_execution\"=>\"#{command_hash['event']}\"}}
    EOT
    hook.reload.configuration[command_hash['event']].should == 1
    node.reload.metadata['last_hook_execution'].should == command_hash['event']
  end

  it "should say if the hook does not handle the event" do
    command_hash['event'] = 'node-unbound-from-policy' # Not included in fixture
    run_hook
    last_response.status.should == 202
    last_response.json['result'].should == "no event handler exists for hook #{command_hash['name']}"
  end

  it "should allow a policy" do
    command_hash['event'] = 'node-bound-to-policy'
    policy = Fabricate(:policy)
    command_hash['policy'] = policy.name
    run_hook
    last_response.status.should == 202
    event_name = last_response.json['name']
    event = Razor::Data::Event[id: event_name]
    event.policy_id.should == policy.id
  end

  it "should require that the event is a real event" do
    command_hash['event'] = 'not-an-event'
    run_hook
    last_response.status.should == 422
    last_response.json['error'].should == 'event must refer to one of node-booted, node-registered, node-bound-to-policy, node-unbound-from-policy, node-deleted, node-facts-changed, node-install-finished'
  end

  it "should respect debug mode" do
    command_hash['debug'] = true
    run_hook
    last_response.status.should == 202
    event_name = last_response.json['name']
    event = Razor::Data::Event[id: event_name]
    event.entry['input'].should_not be_nil
    event.entry['output'].should_not be_nil
  end

  it "should default debug mode to off" do
    run_hook
    last_response.status.should == 202
    event_name = last_response.json['name']
    event = Razor::Data::Event[id: event_name]
    event.entry['input'].should be_nil
    event.entry['output'].should be_nil
  end
end
