require 'spec_helper'

describe Razor::BrokerType.find('puppet') do
  let :broker do
    Razor::Data::Broker.new(:name => 'puppet-test', :broker_type => subject)
  end

  let :node do
    # I wish there were a better way to fake this, I guess.
    mac = (1..6).map {'0123456789ABCDEF'.split('').sample(2).join }
    Razor::Data::Node.new(
      :hw_id    => mac.join,
      :dhcp_mac => mac.join(':'),
      :facts    => {'kernel' => 'simulated', 'osversion' => 'over 9000'},
      :hostname => "#{Faker::Lorem.word}.#{Faker::Internet.domain_name}",
      :root_password => Faker::Company.catch_phrase)
  end

  let :script do broker.install_script_for(node) end

  it "should work without any configuration" do
    script.should be_an_instance_of String
    script.should =~ /gem\b.+\binstall/s
    script.should =~ /puppet\b.+\bagent/s # don't match . == newline
  end

  it "should not specify the gem version when no version in configuration" do
    broker.configuration = {}
    script.should_not =~ /^gem.*-(?:v|-version)/
  end

  it "should install the specified version of the puppet gem" do
    broker.configuration = {'version' => '2.7.34'}
    script.should =~ /-(?:v|-version)[ =]2.7.34\b/
  end

  it "should escape the version string if it has spaces" do
    version = '~> 3.1.0'
    broker.configuration = {'version' => version}

    # We do this the "hard", or at least long, way because we want to ensure
    # that it is correctly shell escaped, and this is better than trying to
    # write up the whole regular expression for that. :)
    line = script.lines.grep(/^gem install/).first
    word = line.shellsplit.find {|x| x =~ /-(v|-version)/}
    word.should =~ /#{Regexp.escape(version)}/
  end

  it "should not specify the server if not in configuration" do
    broker.configuration = {}
    script.should_not =~ /^puppet.*--server/
  end

  it "should specify the server if one is given" do
    server = "puppet.#{Faker::Internet.domain_name}"
    broker.configuration = {'server' => server}

    script.should =~ /^puppet agent .*--server.#{Regexp.escape(server)}\b/
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
