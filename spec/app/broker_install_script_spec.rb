# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "provisioning API" do
  include Rack::Test::Methods

  let :app do Razor::App end
  before :each do
    authorize 'fred', 'dead'
  end

  before :each do
    use_task_fixtures
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
    last_response.json['error'].should == "node #{node.id} not bound to a policy yet"
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
      # Make sure stage_done_url is populating too.
      last_response.body.should == "# there is no meaningful content here"
    end

    it "should return the specified install script for the node" do
      get "/svc/broker/#{node.id}/install?script=install.ps1"

      last_response.status.should == 200
      last_response.content_type.should =~ /text\/plain/
      # Make sure stage_done_url is populating too.
      last_response.body.should == "# sample ps1 file"
    end
    it "should return the specified install script for the node" do
      get "/svc/broker/#{node.id}/install?script=install-template-vars"

      last_response.status.should == 200
      last_response.content_type.should =~ /text\/plain/
      # Make sure stage_done_url is populating too.
      last_response.body.should == <<-TXT.strip
stage_done_url: http://example.org/svc/stage-done/#{node.id}?name=broker
node: #{node.id}
broker: {}
      TXT
    end

    it "should fail if script does not exist" do
      get "/svc/broker/#{node.id}/install?script=does-not-exist"

      last_response.json['error'].should == 'install template does-not-exist.erb does not exist'
      last_response.json['details'].should == "could not find install template 'does-not-exist.erb' for broker '#{policy.broker.name}'"
      last_response.status.should == 404
      last_response.content_type.should =~ /text\/plain/
    end
  end
end
