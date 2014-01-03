require_relative '../spec_helper'
require_relative '../../app'

describe "provisioning API" do
  include Rack::Test::Methods

  let :app do Razor::App end
  before :each do
    authorize 'fred', 'dead'
  end

  before :each do
    use_recipe_fixtures
    use_broker_fixtures
  end

  let :node do
    Fabricate(:node)
  end

  it "should 404 if the node does not exist" do
    get "/svc/broker/#{node.id - 1}/install"
    last_response.status.should == 404
  end

  it "should 409 if the node is not bound to a policy" do
    get "/svc/broker/#{node.id}/install"
    last_response.status.should == 409
  end

  context "with a bound node" do
    let :policy do Fabricate(:policy) end

    before :each do
      node.bind(policy)
      node.save
    end

    it "should return the install script for the node" do
      get "/svc/broker/#{node.id}/install"

      last_response.status.should == 200
      last_response.content_type.should =~ /text\/plain/
      last_response.body.should == "# there is no meaningful content here\n"
    end
  end
end
