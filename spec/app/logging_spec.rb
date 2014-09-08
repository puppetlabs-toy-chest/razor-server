# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "logging" do
  include Rack::Test::Methods

  def app
    Razor::App
  end

  def successful_log(request_postfix)
    get "/svc/log/#{node.id}?msg=message&severity=warn&#{request_postfix}"
    last_response.status.should == 204
    is_in_log(node.events)
    yield node.events.first if block_given?
  end
  def is_in_log(events)
    events.size.should == 1
    events[0].entry["msg"].should == "message"
    events[0].severity.should == "warn"
  end
  context "generic logging api" do
    let (:repo) do Fabricate(:repo) end
    let (:broker) do Fabricate(:broker) end
    let (:task) do Fabricate(:task) end
    let (:node) do Fabricate(:node) end
    it "should store the log message for an existing node" do
      node = Fabricate(:node)

      successful_log("node_id=#{node.id}")
    end
    it "should store the log message for an existing broker" do
      broker = Fabricate(:broker)

      successful_log("broker_id=#{broker.id}") { |entry| entry.broker == broker }
    end
    it "should store the log message for an existing repo" do
      repo = Fabricate(:repo)

      successful_log("repo_id=#{repo.id}") { |entry| entry.repo == repo }
    end
    it "should store the log message for an existing task" do
      task = Fabricate(:task)

      successful_log("task_name=#{URI.escape(task.name)}") { |entry| entry.task == task }
    end
    it "should store the log message for an existing policy" do
      policy = Fabricate(:policy)

      successful_log("policy_id=#{policy.id}") { |entry| entry.policy == policy }
    end
    it "should store the log message for an existing command" do
      command = Fabricate(:command)

      successful_log("command_id=#{command.id}") { |entry| entry.command == command }
    end
    it "should store the log message for many entities" do
      policy = Fabricate(:policy)
      command = Fabricate(:command)

      successful_log("node_id=#{node.id}&broker_id=#{broker.id}&" +
                         "repo_id=#{repo.id}&task_name=#{URI.escape(task.name)}&policy_id=#{policy.id}&" +
                         "command_id=#{command.id}") do |entry|
        entry.broker == broker
        entry.repo == repo
        entry.task == task
        entry.policy == policy
        entry.command == command
      end
    end

    it "should return 404 logging against nonexisting node" do
      get "/svc/log/432?msg=message&severity=warn"
      last_response.status.should == 404
    end

    it "should store the log message for an existing node" do
      node = Fabricate(:node)

      get "/svc/log/#{node.id}?msg=message&severity=warn"
      last_response.status.should == 204
      is_in_log(node.events)
    end

  end
end