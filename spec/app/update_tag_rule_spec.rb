require_relative '../spec_helper'
require_relative '../../app'

describe "update-tag-rule" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  def update_tag_rule(name, rule=nil, force=nil)
    params = { "name" => name }
    params["rule"] = rule unless rule.nil?
    params["force"] = force unless force.nil?
    post '/api/commands/update-tag-rule', params.to_json
  end

  before :each do
    header 'content-type', 'application/json'
  end

  let (:tag) { Fabricate(:tag, :rule => ["=", 1, 1]) }

  it "should require a rule" do
    update_tag_rule(tag.name)
    last_response.status.should == 400
    Tag[:id => tag.id].rule.should == tag.rule
  end

  it "should update an existing tag" do
    update_tag_rule(tag.name, ["!=", 1, 1])

    last_response.status.should == 202
    Tag[:id => tag.id].rule.should == ["!=", 1, 1]
  end
  
  describe "for a tag used by a policy" do
    let (:tag) do
      tag = Fabricate(:tag, :rule => ["=", 1, 1])
      tag.add_policy(Fabricate(:policy))
      tag.save
      tag
    end
    
    it "should not update when 'force' is not present" do
      update_tag_rule(tag.name, ["!=", 1, 1])

      last_response.status.should == 400
      last_response.json["error"].should =~ /used by policies/
      Tag[:id => tag.id].rule.should == tag.rule
    end
    
    it "should update when 'force' is present" do
      update_tag_rule(tag.name, ["!=", 1, 1], true)

      last_response.status.should == 202
      Tag[:id => tag.id].rule.should == ["!=", 1, 1]
    end
  end
end
