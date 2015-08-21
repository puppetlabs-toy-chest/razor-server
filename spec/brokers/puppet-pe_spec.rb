# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::BrokerType.find(name: 'puppet-pe') do
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

  context 'install.erb' do
    let :script do broker.install_script_for(node) end

    it "should work without any configuration" do
      script.should be_an_instance_of String
      script.should include('https://puppet:8140/packages/current/install.bash')
    end

    it "should set the server if given" do
      server = "puppet.#{Faker::Internet.domain_name}"
      broker.configuration = {'server' => server}
      script.should include("https://#{server}:8140/packages/current/install.bash")
    end

    it "should set the version if given" do
      version = 3.times.map do Faker::Number.digit end.join('.')
      broker.configuration = {'version' => version}
      script.should include("https://puppet:8140/packages/#{version}/install.bash")
    end

    it "should set multiple configuration values if given" do
      server = "puppet.#{Faker::Internet.domain_name}"
      version = 3.times.map do Faker::Number.digit end.join('.')
      broker.configuration = {
        'server'      => server,
        'version'    => version
      }

      script.should include("https://#{server}:8140/packages/#{version}/install.bash")
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

  context 'install.ps1.erb' do
    let :script do broker.install_script_for(node, 'install.ps1') end

    it "should work without any configuration" do
      script.should be_an_instance_of String
      script.should include('$version = "latest"')
      script.should include('$master = "puppet"')
      script.should include('$installer = "https://pm.puppetlabs.com/cgi-bin/download.cgi?ver=${version}&dist=win&arch=${arch}"')
    end

    it "should set the server if given" do
      server = "puppet.#{Faker::Internet.domain_name}"
      broker.configuration = {'server' => server}
      script.should include("$master = \"#{server}\"")
    end

    it "should set the version if given" do
      version = 3.times.map do Faker::Number.digit end.join('.')
      broker.configuration = {'version' => version}
      script.should include("$version = \"#{version}\"")
    end

    it "should set the windows_agent_download_url if given" do
      download_url = Faker::Internet.url
      broker.configuration = {'windows_agent_download_url' => download_url}
      script.should include("$installer = \"#{download_url}\"")
    end

    it "should set multiple configuration values if given" do
      server = "puppet.#{Faker::Internet.domain_name}"
      version = 3.times.map do Faker::Number.digit end.join('.')
      download_url = Faker::Internet.url
      broker.configuration = {
          'server'                     => server,
          'version'                    => version,
          'windows_agent_download_url' => download_url
      }

      script.should include("$version = \"#{version}\"")
      script.should include("$master = \"#{server}\"")
      script.should include("$installer = \"#{download_url}\"")
    end
  end
end
