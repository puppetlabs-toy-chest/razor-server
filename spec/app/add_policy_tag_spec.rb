# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "policy-add-tag" do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  def add_policy_tag(name=nil, tag=nil, rule=nil)
    data = {}
    name and data['name'] = name
    tag and data['tag'] = tag
    rule and data['rule'] = rule
    command 'add-policy-tag', data
  end

  context "/api/commands/policy-add-tag" do
    before :each do
      header 'content-type', 'application/json'
      authorize 'fred', 'dead'
    end

    let(:policy) { Fabricate(:policy_with_tag) }
    let(:tag)    { Fabricate(:tag) }
    let(:command_hash) do
      {
          :name => policy.name,
          :tag => policy.tags.first.name,
          :rule => policy.tags.first.rule
      }
    end

    describe Razor::Command::AddPolicyTag do
      it_behaves_like "a command"
    end

    it "should advise that that tag is already on policy" do
      count = policy.tags.count
      add_policy_tag(policy.name, policy.tags.first.name)
      policy.tags(true).count.should == count
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[result]
      last_response.json["result"].should =~ /already on policy/
    end

    it "should add a tag to a policy" do
      count = policy.tags.count
      add_policy_tag(policy.name, tag.name)
      policy.tags(true).count.should == count + 1
      last_response.status.should == 202
    end

    it "should create a new tag and add it to the policy" do
      count = policy.tags.count
      tag_name = 'new_tag'
      matcher  = [ "eq", 1, 1 ]
      add_policy_tag(policy.name, tag_name, matcher)
      policy.tags(true).count.should == count + 1
      last_response.status.should == 202
    end

    it "should fail to add a new tag with no matcher" do
      count = policy.tags.count
      tag_name = 'another_tag'
      add_policy_tag(policy.name, tag_name)
      policy.tags(true).count.should == count
      last_response.status.should == 422
    end
  end
end
