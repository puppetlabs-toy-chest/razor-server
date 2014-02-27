# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "delete-broker" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  def delete_broker(name, force=nil)
    params = { "name" => name }
    post '/api/commands/delete-broker', params.to_json
  end

  before :each do
    header 'content-type', 'application/json'
  end

  it "should delete an existing broker" do
    broker = Fabricate(:broker)
    count = Broker.count
    delete_broker(broker.name)

    last_response.status.should == 202
    Broker[:id => broker.id].should be_nil
    Broker.count.should == count-1
  end

  it "should not delete a broker used by a policy" do
    broker = Fabricate(:broker_with_policy)
    delete_broker(broker.name)
    last_response.status.should == 400
    last_response.json["error"].should =~ /used by policies/
    Broker[:id => broker.id].should == broker
  end

  it "should succeed and do nothing for a nonexistent broker" do
    broker = Fabricate(:broker)
    count = Broker.count

    delete_broker(broker.name + "not really")

    last_response.status.should == 202
    Broker.count.should == count
  end
end
