# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/refresh-repo" do
    let :repo do
      Repo.new(:name => 'magicos', "iso_url" => "file:///dev/null", :task_name => 'testing').save
    end
      
    before :each do
      header 'content-type', 'application/json'
    end

    it "should reject bad JSON" do
      post '/api/commands/refresh-repo', '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/refresh-repo', input
        last_response.status.should == 400
      end
    end

    [[], ["name", "a"]].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/refresh-repo', input
        last_response.status.should == 422
      end
    end

    it "should fail with only bad key present in input" do
      post '/api/commands/refresh-repo', {"cats" => "dogs"}.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end

    it "should fail if an extra key is given, if otherwise good" do
      repo.name
      post '/api/commands/refresh-repo', {
        "repo"      => "magicos",
        "banana"    => "orange",
      }.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end

    it "should fail if a non-existant repo is supplied" do
      post '/api/commands/refresh-repo', {
        "repo"      => "nonexistant",
      }.to_json
      last_response.status.should == 404
      last_response.mime_type.downcase.should == 'application/json'
      JSON.parse(last_response.body)["error"].should =~ /must be the name of an existing repo/
    end

    it "should return the 202, and the URL of the repo if the params are correct and the repo exists" do
      post '/api/commands/refresh-repo', {
        "repo"    => { "name" => repo.name },
      }.to_json

      last_response.status.should == 202
      last_response.mime_type.downcase.should == 'application/json'

      data = JSON.parse(last_response.body)
      data.keys.should =~ %w[command result]
      data["result"].should =~ %r"repo refresh started"
    end

    it "should comform the repo value if given as a string instead of an object" do
      post '/api/commands/refresh-repo', {
        "repo"    => repo.name,
      }.to_json

      last_response.status.should == 202
      last_response.mime_type.downcase.should == 'application/json'

      data = JSON.parse(last_response.body)
      data.keys.should =~ %w[command result]
      data["result"].should =~ %r"repo refresh started"
    end
  end
end
