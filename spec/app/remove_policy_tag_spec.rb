# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::RemovePolicyTag do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  def remove_policy_tag(name=nil, tag=nil)
    data = {}
    name and data['name'] = name
    tag and data['tag'] = tag
    command 'remove-policy-tag', data
  end

  context "/api/commands/policy-remove-tag" do
    before :each do
      header 'content-type', 'application/json'
      authorize 'fred', 'dead'
    end

    let(:tag)    { Fabricate(:tag) }
    let(:policy) { Fabricate(:policy_with_tag) }
    let(:command_hash) do
      {
          'name' => policy.name,
          'tag' => policy.tags.first.name
      }
    end

    it_behaves_like "a command"

    it "should remove a tag from a policy" do
      count = policy.tags.count
      remove_policy_tag(policy.name, policy.tags.first.name)
      last_response.status.should == 202
      policy.tags(true).count.should == count-1
    end

    it "should advise that that tag wasnt on policy" do
      count = policy.tags.count
      remove_policy_tag(policy.name, tag.name)
      policy.tags(true).count.should == count
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[result]
      last_response.json["result"].should =~ /was not on policy/
    end
  end
end
