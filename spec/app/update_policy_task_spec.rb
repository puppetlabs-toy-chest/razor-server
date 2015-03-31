# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdatePolicyTask do
  include Razor::Test::Commands
  before 'each' do
    use_task_fixtures
  end

  let(:app) { Razor::App }

  let(:policy) do
    Fabricate(:policy)
  end
  let(:task) do
    Fabricate(:task)
  end
  let(:command_hash) do
    {
        'policy' => policy.name,
        'task' => 'some_os',
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_policy_task(data)
    command 'update-policy-task', data
  end

  it_behaves_like "a command"

  it "changes policy's task" do
    previous_task = policy.task
    update_policy_task(command_hash)
    new_task = Razor::Data::Policy[name: command_hash['policy']].task
    new_task.should_not == previous_task
    new_task.name.should == 'some_os'
    last_response.json['result'].should == "policy #{policy.name} updated to use task some_os"
  end

  it "leaves policy's task when the same" do
    policy.task_name = 'some_os'
    policy.save
    previous_task = policy.task
    update_policy_task(command_hash)
    new_task = Razor::Data::Policy[name: command_hash['policy']].task
    new_task.should_not == previous_task
    new_task.name.should == 'some_os'
    last_response.json['result'].should == "no changes; policy #{policy.name} already uses task some_os"
  end

  it "should fail if the policy is missing" do
    command_hash.delete('policy')
    update_policy_task(command_hash)
    last_response.status.should == 422
  end

  it "should fail if the task is missing" do
    command_hash.delete('task')
    update_policy_task(command_hash)
    last_response.status.should == 422
  end

  it "should allow no_task" do
    policy = Razor::Data::Policy[name: command_hash['policy']]
    policy.task_name = Fabricate(:task).name
    policy.task.should_not == policy.repo.task
    command_hash.delete('task')
    command_hash['no_task'] = true
    update_policy_task(command_hash)
    last_response.status.should == 202
    policy.reload
    policy.task.should == policy.repo.task
    policy.task_name.should be_nil
  end

  it "should disallow both a task and no_task" do
    command_hash['no_task'] = true
    update_policy_task(command_hash)
    last_response.status.should == 422
  end
end
