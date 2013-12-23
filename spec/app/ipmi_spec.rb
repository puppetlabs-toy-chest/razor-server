require_relative '../spec_helper'
require_relative '../../app'

describe "set-node-ipmi-credentials" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  let(:url) { '/api/commands/set-node-ipmi-credentials' }
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
