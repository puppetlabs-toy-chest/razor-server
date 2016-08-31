# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdatePolicyBroker do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:policy) do
    Fabricate(:policy)
  end
  let(:broker) do
    Fabricate(:broker)
  end
  let(:command_hash) do
    {
        'policy' => policy.name,
        'broker' => broker.name,
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_policy_broker(data)
    command 'update-policy-broker', data
  end

  it_behaves_like "a command"

  it "changes policy's broker" do
    previous_broker = policy.broker
    update_policy_broker(command_hash)
    new_broker = Razor::Data::Policy[name: command_hash['policy']].broker
    new_broker.should_not == previous_broker
    new_broker.name.should == broker.name
    last_response.json['result'].should == "policy #{policy.name} updated to use broker #{broker.name}"
  end

  it "leaves policy's broker when the same" do
    previous_broker = policy.broker
    policy.broker = broker
    policy.save
    update_policy_broker(command_hash)
    new_broker = Razor::Data::Policy[name: command_hash['policy']].broker
    new_broker.should_not == previous_broker
    new_broker.name.should == broker.name
    last_response.json['result'].should == "no changes; policy #{policy.name} already uses broker #{broker.name}"
  end

  it "should fail if the policy is missing" do
    command_hash.delete('policy')
    update_policy_broker(command_hash)
    last_response.status.should == 422
  end

  it "should fail if the broker is missing" do
    command_hash.delete('broker')
    update_policy_broker(command_hash)
    last_response.status.should == 422
  end
end
