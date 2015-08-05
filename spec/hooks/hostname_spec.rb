# -*- encoding: utf-8 -*-
require_relative "../spec_helper"

describe 'hostname hook' do
  let :hook_type do Razor::HookType.find(name: 'hostname') end
  include TorqueBox::Injectors
  let :queue do fetch('/queues/razor/sequel-hooks-messages') end

  let :node do
    # I wish there were a better way to fake this, I guess.
    mac = (1..6).map {'0123456789ABCDEF'.split('').sample(2).join }
    Razor::Data::Node.new(
        :hw_info  => ["mac=#{mac.join("-")}"],
        :dhcp_mac => mac.join(':'),
        :facts    => {'kernel' => 'simulated', 'osversion' => 'over 9000'},
        :hostname => "#{Faker::Lorem.word}.#{Faker::Internet.domain_name}",
        :root_password => Faker::Company.catch_phrase).save
  end

  let :policy do Fabricate(:policy) end

  it "should not work without any configuration" do
    arguments = {:name => 'hostname-test', :hook_type => Razor::HookType.find(name: 'hostname')}
    expect { Razor::Data::Hook.new(arguments).save }.
        to raise_error(Sequel::ValidationFailed, "configuration key 'policy' is required by this hook type, but was not supplied, " +
                                                 "configuration key 'hostname_pattern' is required by this hook type, but was not supplied")
  end
  it "should fail without existing policy" do
    arguments = {:name => 'hostname-test', :hook_type => Razor::HookType.find(name: 'hostname'),
                 :configuration => {'hostname_pattern' => '${policy}${count}.com'}}
    expect { Razor::Data::Hook.new(arguments).save }.
           to raise_error(Sequel::ValidationFailed, "configuration key 'policy' is required by this hook type, but was not supplied")
  end
  it "should fail without existing hostname_pattern" do
    arguments = {:name => 'hostname-test', :hook_type => Razor::HookType.find(name: 'hostname'),
                 :configuration => {'policy' => policy.name}}
    expect { Razor::Data::Hook.new(arguments).save }.
           to raise_error(Sequel::ValidationFailed, "configuration key 'hostname_pattern' is required by this hook type, but was not supplied")
  end
  it "should succeed with proper arguments" do
    arguments = {:name => 'hostname-test', :hook_type => Razor::HookType.find(name: 'hostname'),
                 :configuration => {'policy' => policy.name, 'hostname_pattern' => '${policy}${count}.com'}}
    Razor::Data::Hook.new(arguments).save
  end
  it "should perform as expected" do
    arguments = {:name => 'hostname-test', :hook_type => Razor::HookType.find(name: 'hostname'),
                 :configuration => {'policy' => policy.name, 'hostname_pattern' => '${policy}${count}.com'}}
    # Done this way (condensed into one test) to save time during test
    # execution, since spinning up jruby instances is slow.
    hook = Razor::Data::Hook.new(arguments).save
    hook.configuration['policy'].should == policy.name
    hook.configuration['counter'].should == 1
    Razor::Data::Hook.trigger('node-bound-to-policy', node: node, policy: policy)
    queue.count_messages.should == 1
    run_message(queue.receive)
    hook.reload
    hook.configuration['policy'].should == policy.name
    hook.configuration['counter'].should == 2
    node.reload
    node.metadata['hostname'].should == policy.name + '1' + '.com'
  end
end
