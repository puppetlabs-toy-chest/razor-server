# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "create tag command" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-tag" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:command_hash) do
      { :name => "test",
        :rule => ["=", ["fact", "kernel"], "Linux"] }
    end

    def create_tag(input = nil)
      input ||= command_hash
      command 'create-tag', input
    end

    describe Razor::Command::CreateTag do
      it_behaves_like "a command"
    end

    it "should reject bad JSON" do
      create_tag '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        create_tag input
        last_response.status.should == 400
      end
    end

    it "should fail if the name is an empty string" do
      create_tag(name: '', rule: ['=', true, true])
      last_response.status.should == 422
      last_response.json['error'].should ==
        'name must be at least 1 characters in length, but is only 0 characters long'
    end

    # Successful creation
    it "should return 202, and the URL of the tag" do
      create_tag

      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[id name spec]

      last_response.json["id"].should =~ %r'/api/collections/tags/test\Z'
    end

    it "should create an tag record in the database" do
      create_tag

      Razor::Data::Tag[:name => command_hash[:name]].should be_an_instance_of Razor::Data::Tag
    end
  end
end
