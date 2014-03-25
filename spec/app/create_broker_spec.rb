# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

require 'pathname'

describe "create broker command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-broker" do
    before :each do
      header 'content-type', 'application/json'

      Razor.config['broker_path'] =
        (Pathname(__FILE__).dirname.parent + 'fixtures' + 'brokers').realpath.to_s
    end

    let :broker_command do
      { 'name'        => Faker::Commerce.product_name,
        'broker-type' => 'test'
      }
    end

    def create_broker(command)
      post '/api/commands/create-broker', command.to_json
      command
    end

    it "should reject bad JSON" do
      post '/api/commands/create-broker', '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/create-broker', input
        last_response.status.should == 400
      end
    end

    it "should fail if the named broker does not actually exist" do
      create_broker broker_command.merge 'broker-type' => 'no-such-broker-for-me'

      last_response.status.should == 404
      last_response.json['error'].should == 'attribute broker-type must refer to an existing instance'
    end

    it "should fail cleanly if 'configuration' is a string" do
      broker_command['configuration'] = '{"arg1": "value1"}'
      create_broker broker_command

      last_response.status.should == 422
      last_response.json['error'].should == "expected object but got string"
    end
    # Successful creation
    it "should return 202, and the URL of the broker" do
      command = create_broker broker_command

      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[name id spec]

      name = URI.escape(command['name'])
      last_response.json["id"].should =~ %r'/api/collections/brokers/#{name}\Z'
    end

    it "should create an broker record in the database" do
      command = create_broker broker_command

      Razor::Data::Broker[:name => command['name']].should be_an_instance_of Razor::Data::Broker
    end
  end
end
