# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::SetNodeIPMICredentials do
  include Razor::Test::Commands

  let(:app)  { Razor::App }
  let(:node) { Fabricate(:node).save }
  let(:command_hash) { { "name" => node.name } }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it_behaves_like "a command"

  it "should report 'no such node' if the name isn't found" do
    command 'set-node-ipmi-credentials', {:name => 'bananaman'}
    last_response.status.should == 404
  end

  it "should update the node data correctly" do
    node.ipmi_hostname.should be_nil
    node.ipmi_username.should be_nil
    node.ipmi_password.should be_nil

    update = {
      'ipmi_hostname' => Faker::Internet.ip_v4_address,
      'ipmi_username' => Faker::Internet.user_name,
      'ipmi_password' => Faker::Internet.password[0..19]
    }

    command 'set-node-ipmi-credentials', {:name => node.name}.merge(update)
    last_response.status.should == 202
    node.reload                 # refresh from the database, plz

    node.ipmi_hostname.should == update['ipmi_hostname']
    node.ipmi_username.should == update['ipmi_username']
    node.ipmi_password.should == update['ipmi_password']
  end
end

describe Razor::Command::RebootNode do
  include Razor::Test::Commands
  include TorqueBox::Injectors

  let(:app)   { Razor::App }
  let(:node)  { Fabricate(:node_with_ipmi).save }
  let(:queue) { fetch('/queues/razor/sequel-instance-messages') }
  let(:command_hash) { { "name" => node.name } }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it_behaves_like "a command"

  it "should work" do
    command 'reboot-node', {'name' => node.name}
    last_response.status.should == 202
  end

  context "RBAC" do
    around :each do |spec|
      Tempfile.open('shiro.ini') do |config|
        config.print <<EOT
[main]
[users]
can=can,reboot
none=none
[roles]
reboot=commands:reboot-node:*
EOT
        config.flush
        Razor.config['auth.config'] = config.path

        # ...and, thankfully, all our cleanup happens auto-magically.
        spec.call
      end
    end

    it "should reject an unauthenticated request" do
      command 'reboot-node', {'name' => node.name}
      last_response.status.should == 401
    end

    it "should reject all reboot requests with no reboot rights" do
      authorize 'none', 'none'
      command 'reboot-node', {'name' => node.name}
      last_response.status.should == 403
    end

    it "should accept a reboot request with reboot rights" do
      authorize 'can', 'can'
      command 'reboot-node', {'name' => node.name}
      last_response.status.should == 202
    end
  end

  it "should 404 if the node does not exist" do
    command 'reboot-node', {'name' => node.name + '-plus'}
    last_response.status.should == 404
  end

  it "should 422 if the node has no IPMI credentials" do
    node.set(:ipmi_hostname => nil).save
    command 'reboot-node', {'name' => node.name}
    last_response.status.should == 422
  end

  it "should publish the `reboot!` message" do
    expect {
      command 'reboot-node', {'name' => node.name}
      last_response.status.should == 202
    }.to have_published({
      'class'     => node.class.name,
      'instance'  => node.pk_hash,
      'message'   => 'reboot!',
      'arguments' => []
    }).on(queue)
  end
end

describe Razor::Command::SetNodeDesiredPowerState do
  include Razor::Test::Commands

  let(:app)   { Razor::App }
  let(:node)  { Fabricate(:node_with_ipmi).save }
  let(:command_hash) { { "name" => node.name } }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it_behaves_like "a command"

  it "should 404 if the node does not exist" do
    command 'set-node-desired-power-state', {name: node.name + '-really'}
    last_response.status.should == 404
  end

  it "should accept null for 'ignored'" do
    command 'set-node-desired-power-state', {name: node.name, to: nil}
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to ignored (null)"}
  end

  it "should accept 'on'" do
    command 'set-node-desired-power-state', {name: node.name, to: 'on'}
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to on"}
  end

  it "should accept 'off'" do
    command 'set-node-desired-power-state', {name: node.name, to: 'off'}
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to off"}
  end

  ([0, 1, true, false] + %w{true false up down yes no 1 0}).each do |bad|
    it "should reject #{bad.inspect}" do
      command 'set-node-desired-power-state', {name: node.name, to: bad}
      last_response.status.should == 422
    end
  end
end
