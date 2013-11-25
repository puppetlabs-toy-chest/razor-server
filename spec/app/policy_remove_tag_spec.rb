require_relative '../spec_helper'
require_relative '../../app'

describe "policy-remove-tag" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  def policy_remove_tag(name=nil, tag=nil)
    post '/api/commands/policy-remove-tag', { "name" => name, "tag" => tag }.to_json
  end

  context "/api/commands/policy-remove-tag" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:tag)    { Fabricate(:tag) }
    let(:policy) { Fabricate(:policy_with_tag) }

    it "should remove a tag from a policy" do
      count = policy.tags.count
      policy_remove_tag(policy.name, policy.tags.first.name)
      policy.tags(true).count.should == count-1
      last_response.status.should == 202
    end

    it "should advise that that tag wasnt on policy" do
      count = policy.tags.count
      policy_remove_tag(policy.name, tag.name)
      policy.tags(true).count.should == count
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[result]
      last_response.json["result"].should =~ /was not on policy/
    end

    it "should fail to with no policy name" do
      policy_remove_tag(nil, tag.name)
      last_response.status.should == 400
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /Supply policy name/
    end

    it "should fail to with no tag name" do
      policy_remove_tag(policy.name)
      last_response.status.should == 400
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[error]
      last_response.json["error"].should =~ /name of the tag/
    end
  end
end
