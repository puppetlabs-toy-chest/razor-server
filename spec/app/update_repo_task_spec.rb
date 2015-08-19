# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdateRepoTask do
  include Razor::Test::Commands

  before :each do
    use_task_fixtures
  end

  let(:app) { Razor::App }

  let(:repo) do
    Fabricate(:repo)
  end
  let(:task) do
    Fabricate(:task)
  end
  let(:command_hash) do
    {
        'repo' => repo.name,
        'task' => 'some_os',
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_repo_task(data)
    command 'update-repo-task', data
  end

  it_behaves_like "a command"

  it "changes repo's task" do
    previous_task = repo.task
    update_repo_task(command_hash)
    new_task = Razor::Data::Repo[name: command_hash['repo']].task
    new_task.should_not == previous_task
    new_task.name.should == 'some_os'
    last_response.json['result'].should == "repo #{repo.name} updated to use task some_os"
  end

  it "leaves repo's task when the same" do
    repo.task_name = 'some_os'
    repo.save
    previous_task = repo.task
    update_repo_task(command_hash)
    new_task = Razor::Data::Repo[name: command_hash['repo']].task
    new_task.should_not == previous_task
    new_task.name.should == 'some_os'
    last_response.json['result'].should == "no changes; repo #{repo.name} already uses task some_os"
  end

  it "should fail if the repo is missing" do
    command_hash.delete('repo')
    update_repo_task(command_hash)
    last_response.status.should == 422
  end

  it "should fail if the task is missing" do
    command_hash.delete('task')
    update_repo_task(command_hash)
    last_response.status.should == 422
  end
end
