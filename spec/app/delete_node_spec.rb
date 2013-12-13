require_relative '../spec_helper'
require_relative '../../app'

describe "delete-node" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  def delete_node(name)
    post '/api/commands/delete-node', { "name" => name }.to_json
  end

  context "/api/commands/delete-node" do
    before :each do
      header 'content-type', 'application/json'
    end

    it "should delete an existing node" do
      node = Fabricate(:node)
      count = Node.count
      delete_node(node.name)

      last_response.status.should == 202
      Node[:id => node.id].should be_nil
      Node.count.should == count-1
    end

    it "should delete an existing node that has been tagged" do
      node = Fabricate(:node)
      node.add_tag(Fabricate(:tag))

      count = Node.count
      delete_node(node.name)

      last_response.status.should == 202
      Node[:id => node.id].should be_nil
      Node.count.should == count-1
    end

    it "should succeed and do nothing for a nonexistent node" do
      node = Fabricate(:node)
      count = Node.count

      delete_node(node.name + "not really")

      last_response.status.should == 202
      Node.count.should == count
    end
  end
end
