require_relative '../spec_helper'
require_relative '../../app'

describe "unbind-node" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  def unbind_node(name)
    post '/api/commands/unbind-node', { "name" => name }.to_json
  end

  context "/api/commands/unbind-node" do
    before :each do
      header 'content-type', 'application/json'
    end

    it "should unbind a bound node" do
      node = Fabricate(:bound_node)
      unbind_node(node.name)

      last_response.status.should == 202
      Node[:id => node.id].policy.should be_nil
    end

    it "should succeed for an unbound node" do
      node = Fabricate(:node)
      unbind_node(node.name)

      last_response.status.should == 202
    end

    it "should succeed for a nonexistent node" do
      unbind_node("not really an existing node")
      last_response.status.should == 202
    end
  end
end
