# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdatePolicyRepo do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:policy) do
    Fabricate(:policy)
  end
  let(:repo) do
    Fabricate(:repo)
  end
  let(:command_hash) do
    {
        'policy' => policy.name,
        'repo' => repo.name,
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_policy_repo(data)
    command 'update-policy-repo', data
  end

  it_behaves_like "a command"

  it "changes policy's repo" do
    previous_repo = policy.repo
    update_policy_repo(command_hash)
    new_repo = Razor::Data::Policy[name: command_hash['policy']].repo
    new_repo.should_not == previous_repo
    new_repo.name.should == repo.name
    last_response.json['result'].should == "policy #{policy.name} updated to use repo #{repo.name}"
  end

  it "leaves policy's repo when the same" do
    previous_repo = policy.repo
    policy.repo = repo
    policy.save
    update_policy_repo(command_hash)
    new_repo = Razor::Data::Policy[name: command_hash['policy']].repo
    new_repo.should_not == previous_repo
    new_repo.name.should == repo.name
    last_response.json['result'].should == "no changes; policy #{policy.name} already uses repo #{repo.name}"
  end

  it "should fail if the policy is missing" do
    command_hash.delete('policy')
    update_policy_repo(command_hash)
    last_response.status.should == 422
  end

  it "should fail if the repo is missing" do
    command_hash.delete('repo')
    update_policy_repo(command_hash)
    last_response.status.should == 422
  end
end
