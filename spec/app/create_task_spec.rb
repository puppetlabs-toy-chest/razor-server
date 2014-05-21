# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::CreateTask do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-task" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:command_hash) do
      { :name => "task",
        :os => "SomeOS",
        :templates => { "name" => "erb template" },
        :boot_seq => { 1 => "boot_install", "default" => "boot_local" } }
    end

    def create_task(input = nil)
      command 'create-task', (input || command_hash)
    end

    it_behaves_like "a command"

    it "should reject bad JSON" do
      create_task '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        create_task input
        last_response.status.should == 400
      end
    end

    it "should fail if boot_seq hash has keys that are strings != 'default'" do
      command_hash[:boot_seq]["sundays"] = "local"
      create_task
      last_response.status.should == 422
    end

    it "should fail if templates is not a hash" do
      command_hash[:templates] = ["stuff"]
      create_task
      last_response.status.should == 422
    end

    # Successful creation
    it "should return 202, and the URL of the task" do
      create_task
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[id name spec]

      last_response.json["id"].should =~ %r'/api/collections/tasks/task\Z'
    end

    it "should create an repo record in the database" do
      create_task

      Razor::Data::Task[:name => command_hash[:name]].should be_an_instance_of Razor::Data::Task
    end
  end
end
