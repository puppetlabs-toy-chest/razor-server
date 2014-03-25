# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::BrokerType.find(name: 'puppet') do
  let :broker do
    Razor::Data::Broker.new(:name => 'puppet-test', :broker_type => subject)
  end

  let :node do
    # I wish there were a better way to fake this, I guess.
    mac = (1..6).map {'0123456789ABCDEF'.split('').sample(2).join }
    Razor::Data::Node.new(
      :hw_info  => ["mac=#{mac.join("-")}"],
      :dhcp_mac => mac.join(':'),
      :facts    => {'kernel' => 'simulated', 'osversion' => 'over 9000'},
      :hostname => "#{Faker::Lorem.word}.#{Faker::Internet.domain_name}",
      :root_password => Faker::Company.catch_phrase)
  end

  let :script do broker.install_script_for(node) end

  it "should work without any configuration" do
    script.should be_an_instance_of String
    script.should =~ /yum -y install puppet/s
    script.should =~ /service puppet start/s # don't match . == newline
    script.should_not =~ /puppet resource ini_setting/
  end

  it "should not specify the server if not in configuration" do
    broker.configuration = {}
    script.should_not =~ /setting=server/
  end

  it "should specify the server if one is given" do
    server = "puppet.#{Faker::Internet.domain_name}"
    broker.configuration = {'server' => server}

    script.should =~ /setting=server value=#{Regexp.escape(server)}/
  end

  it "should set the certname if given" do
    certname = "agent.#{Faker::Internet.domain_name}"
    broker.configuration = {'certname' => certname}

    script.should =~ /setting=certname value=#{Regexp.escape(certname)}/
  end

  it "should set the environment if given" do
    environment = "bananafudge"
    broker.configuration = {'environment' => environment}

    script.should =~ /setting=environment value=#{Regexp.escape(environment)}/
  end

  it "should set multiple configuration values if given" do
    server = "puppet.#{Faker::Internet.domain_name}"
    certname = "agent.#{Faker::Internet.domain_name}"
    environment = "bananafudge"
    broker.configuration = {
      'server'      => server,
      'certname'    => certname,
      'environment' => environment
    }

    script.should =~ /setting=server value=#{Regexp.escape(server)}/
    script.should =~ /setting=certname value=#{Regexp.escape(certname)}/
    script.should =~ /setting=environment value=#{Regexp.escape(environment)}/
  end

  # This is not the most robust check for correctness in the world, but it
  # does capture "parsing errors", which can help if we somehow bust things up
  # in the template by dropping Ruby in or something.
  context "syntax checking with combinations of configuration" do
    versions = [nil, '2.7.34', '~> 3.1']
    servers  = [nil, 'puppet', 'puppet.' + Faker::Internet.domain_name,
      Faker::Internet.ip_v4_address, Faker::Internet.ip_v6_address]

    versions.each do |version|
      servers.each do |server|
        it "version #{version.inspect} and server #{server.inspect}" do
          config = {}
          version and config['version'] = version
          server  and config['server']  = server
          broker.configuration = config

          # turn on '-n' for "don't execute any commands"
          system('/bin/bash', '-n', '-c', script) or raise "failed syntax check"
        end
      end
    end
  end
end
