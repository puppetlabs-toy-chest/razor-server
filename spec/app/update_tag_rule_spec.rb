# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "update-tag-rule" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

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

  it "should not untag an already tagged node" do
    node = Fabricate(:node)
    tag.add_node(node)
    tag.save

    update_tag_rule(tag.name, ["!=", 1, 1])
    last_response.status.should == 202

    node.refresh.tags.should == [ tag.refresh ]
  end

  it "should not tag a newly matching node" do
    tag.rule = ["!=", 1, 1]
    tag.save
    node = Fabricate(:node)


    update_tag_rule(tag.name, ["=", 1, 1])
    last_response.status.should == 202
    Node[:id => node.id].tags.should be_empty
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
