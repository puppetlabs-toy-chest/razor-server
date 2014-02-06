require_relative '../spec_helper'
require_relative '../../app'

describe "set-node-ipmi-credentials" do
  include Rack::Test::Methods

  let(:app)  { Razor::App }
  let(:url)  { '/api/commands/set-node-ipmi-credentials' }
  let(:node) { Fabricate(:node).save }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it "should fail if the node name is not given" do
    post url, {}.to_json
    last_response.status.should == 400
  end

  it "should report 'no such node' if the name isn't found" do
    post url, {:name => 'bananaman'}.to_json
    last_response.status.should == 404
  end

  it "should update the node data correctly" do
    node.ipmi_hostname.should be_nil
    node.ipmi_username.should be_nil
    node.ipmi_password.should be_nil

    update = {
      'ipmi-hostname' => Faker::Internet.ip_v4_address,
      'ipmi-username' => Faker::Internet.user_name,
      'ipmi-password' => Faker::Internet.password[0..19]
    }

    post url, {:name => node.name}.merge(update).to_json
    node.reload                 # refresh from the database, plz

    node.ipmi_hostname.should == update['ipmi-hostname']
    node.ipmi_username.should == update['ipmi-username']
    node.ipmi_password.should == update['ipmi-password']
  end
end

describe "reboot-node" do
  include Rack::Test::Methods
  include TorqueBox::Injectors

  let(:app)   { Razor::App }
  let(:url)   { '/api/commands/reboot-node' }
  let(:node)  { Fabricate(:node_with_ipmi).save }
  let(:queue) { fetch('/queues/razor/sequel-instance-messages') }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it "should fail if no node is included" do
    post url, {}.to_json
    last_response.status.should == 400
  end

  it "should work" do
    post url, {'name' => node.name}.to_json
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
      post url, {'name' => node.name}.to_json
      last_response.status.should == 401
    end

    it "should reject all reboot requests with no reboot rights" do
      authorize 'none', 'none'
      post url, {'name' => node.name}.to_json
      last_response.status.should == 403
    end

    it "should accept a reboot request with reboot rights" do
      authorize 'can', 'can'
      post url, {'name' => node.name}.to_json
      last_response.status.should == 202
    end
  end

  it "should 404 if the node does not exist" do
    post url, {'name' => node.name + '-plus'}.to_json
    last_response.status.should == 404
  end

  it "should 422 if the node has no IPMI credentials" do
    node.set(:ipmi_hostname => nil).save
    post url, {'name' => node.name}.to_json
    last_response.status.should == 422
  end

  it "should publish the `reboot!` message" do
    expect {
      post url, {'name' => node.name}.to_json
      last_response.status.should == 202
    }.to have_published({
      'class'     => node.class.name,
      'instance'  => node.pk_hash,
      'message'   => 'reboot!',
      'arguments' => []
    }).on(queue)
  end
end

describe "set-node-desired-power-state" do
  include Rack::Test::Methods

  let(:app)   { Razor::App }
  let(:url)   { '/api/commands/set-node-desired-power-state' }
  let(:node)  { Fabricate(:node_with_ipmi).save }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it "should fail if the name is absent" do
    post url, {}.to_json
    last_response.status.should == 400
  end

  it "should 404 if the node does not exist" do
    post url, {name: node.name + '-really'}.to_json
    last_response.status.should == 404
  end

  it "should accept null for 'ignored'" do
    post url, {name: node.name, to: nil}.to_json
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to ignored (null)"}
  end

  it "should accept 'on'" do
    post url, {name: node.name, to: 'on'}.to_json
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to on"}
  end

  it "should accept 'off'" do
    post url, {name: node.name, to: 'off'}.to_json
    last_response.status.should == 202
    last_response.json.should == {'result' => "set desired power state to off"}
  end

  ([0, 1, true, false] + %w{true false up down yes no 1 0}).each do |bad|
    it "should reject #{bad.inspect}" do
      post url, {name: node.name, to: bad}.to_json
      last_response.status.should == 400
    end
  end
end
