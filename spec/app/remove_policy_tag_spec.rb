# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "policy-remove-tag" do
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

    it "should fail to with no policy name" do
      remove_policy_tag(nil, tag.name)
      last_response.status.should == 422
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /required attribute name is missing/
    end

    it "should fail to with no tag name" do
      remove_policy_tag(policy.name)
      last_response.status.should == 422
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /required attribute tag is missing/
    end
  end
end
