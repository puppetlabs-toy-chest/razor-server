require_relative '../spec_helper'
require_relative '../../app'

describe "reinstall-node" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  def reinstall_node(name)
    post '/api/commands/reinstall-node', { "name" => name }.to_json
  end

  context "/api/commands/reinstall-node" do
    before :each do
      header 'content-type', 'application/json'
    end

    it "should reinstall a bound node" do
      node = Fabricate(:bound_node)
      reinstall_node(node.name)

      last_response.status.should == 202
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
      node.reload
      node.policy.should be_nil
      node.installed.should be_nil
      node.installed_at.should be_nil
    end

    it "should succeed for an unbound node" do
      node = Fabricate(:node)
      reinstall_node(node.name)

      last_response.status.should == 202
    end

    it "should succeed for a nonexistent node" do
      reinstall_node("not really an existing node")
      last_response.status.should == 202
    end
  end
end
