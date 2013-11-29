require_relative '../spec_helper'
require_relative '../../app'

describe "policy-add-tag" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  def policy_add_tag(name=nil, tag=nil, rule=nil)
    post '/api/commands/policy-add-tag', { "name" => name, "tag" => tag, "rule" => rule }.to_json
  end

  context "/api/commands/policy-add-tag" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:policy) { Fabricate(:policy_with_tag) }
    let(:tag)    { Fabricate(:tag) }

    it "should advise that that tag is already on policy" do
      count = policy.tags.count
      policy_add_tag(policy.name, policy.tags.first.name)
      policy.tags(true).count.should == count
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[result]
      last_response.json["result"].should =~ /already on policy/
    end

    it "should add a tag to a policy" do
      count = policy.tags.count
      policy_add_tag(policy.name, tag.name)
      policy.tags(true).count.should == count + 1
      last_response.status.should == 202
    end

    it "should create a new tag and add it to the policy" do
      count = policy.tags.count
      tag_name = 'new_tag'
      matcher  = [ "eq", 1, 1 ]
      policy_add_tag(policy.name, tag_name, matcher)
      policy.tags(true).count.should == count + 1
      last_response.status.should == 202
    end

    it "should fail to add a new tag with no matcher" do
      count = policy.tags.count
      tag_name = 'another_tag'
      policy_add_tag(policy.name, tag_name)
      policy.tags(true).count.should == count
      last_response.status.should == 400
    end

    it "should fail to with no policy name" do
      policy_add_tag(nil, tag.name)
      last_response.status.should == 400
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /Supply policy name/
    end

    it "should fail to with no tag name" do
      policy_add_tag(policy.name)
      last_response.status.should == 400
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /name of the tag/
    end
  end
end
