# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "delete-tag" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  let(:tag) { Fabricate(:tag) }
  let(:command_hash) { { "name" => tag.name } }
  before :each do
    authorize 'fred', 'dead'
  end

  def delete_tag(name, force=nil)
    params = { "name" => name }
    params["force"] = force unless force.nil?
    command 'delete-tag', params
  end

  before :each do
    header 'content-type', 'application/json'
  end

  describe Razor::Command::DeleteTag do
    it_behaves_like "a command"
  end

  it "should delete an existing tag" do
    tag = Fabricate(:tag)
    count = Tag.count
    delete_tag(tag.name)

    last_response.status.should == 202
    Tag[:id => tag.id].should be_nil
    Tag.count.should == count-1
  end

  describe "for a tag used by a policy" do
    let (:tag) do
      tag = Fabricate(:tag)
      tag.add_policy(Fabricate(:policy))
      tag.save
      tag
    end

    it "should not delete when 'force' is not present" do
      delete_tag(tag.name)
      last_response.status.should == 400
      last_response.json["error"].should =~ /used by policies/
      Tag[:id => tag.id].should == tag
    end

    it "should delete when 'force' is true" do
      delete_tag(tag.name, true)
      last_response.status.should == 202
      Tag[:id => tag.id].should be_nil
    end
  end

  describe "for a tag attached to a node" do
    let (:tag) do
      tag = Fabricate(:tag)
      tag.add_node(Fabricate(:node))
      tag.save
      tag
    end

    it "should delete when 'force' is not present" do
      delete_tag(tag.name)
      last_response.status.should == 202
      Tag[:id => tag.id].should be_nil
    end

    it "should delete when 'force' is true" do
      delete_tag(tag.name, true)
      last_response.status.should == 202
      Tag[:id => tag.id].should be_nil
    end
  end

  it "should succeed and do nothing for a nonexistent tag" do
    tag = Fabricate(:tag)
    count = Tag.count

    delete_tag(tag.name + "not really")

    last_response.status.should == 202
    Tag.count.should == count
  end
end
