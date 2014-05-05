# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/set-repo-source" do
    let :repo do
      Repo.new(:name => 'magicos', "iso_url" => "file:///dev/null", :task_name => 'testing').save
    end

    before :each do
      header 'content-type', 'application/json'
    end

    it "should reject bad JSON" do
      post '/api/commands/set-repo-source', '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/set-repo-source', input
        last_response.status.should == 400
      end
    end

    [[], ["name", "a"]].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/set-repo-source', input
        last_response.status.should == 422
      end
    end

    it "should fail with only bad key present in input" do
      post '/api/commands/set-repo-source', {"cats" => "> dogs"}.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
      # @todo danielp 2013-06-26: should do something to assert we got a good
      # error message or messages out of the system; see comments in app.rb
      # for details about why that is delayed.
    end

    it "should fail if only the repo is given" do
      repo.name
      post '/api/commands/set-repo-source', {"repo" => {"name" => "magicos"}}.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end

    it "should fail if only the iso_url is given" do
      post '/api/commands/set-repo-source', {"iso_url" => "file:///dev/null"}.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end

    it "should fail if attempting to update a repo that does not exist" do
      post '/api/commands/set-repo-source', {
        "repo"      => {"name" => "nonexistant"},
        "iso-url"   => "file:///dev/null",
      }.to_json
      last_response.status.should == 404
      last_response.mime_type.downcase.should == 'application/json'
      JSON.parse(last_response.body)["error"].should =~ /must be the name of an existing repo/
    end

    it "should fail if an extra key is given, if otherwise good" do
      post '/api/commands/set-repo-source', {
        "repo"      => { "name" => repo.name },
        "iso-url"   => "file:///dev/null",
        "banana"    => "> orange",
      }.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
      JSON.parse(last_response.body)["error"].should =~ /extra attribute banana was present/
    end

    [ true, false ].each do |test|
      it "should accept #{test} as a value for refresh" do
        post '/api/commands/set-repo-source', {
          "repo"    => { "name" => repo.name },
          "iso-url" => "file:///dev/random",
          "refresh" => test,
        }.to_json
        last_response.status.should == 202
      end
    end

    it "should not except non true/false values for refresh" do
      post '/api/commands/set-repo-source', {
        "repo"    => { "name" => repo.name },
        "iso-url" => "file:///dev/random",
        "refresh" => "garbage",
      }.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
      JSON.parse(last_response.body)["error"].should =~ /refresh should be one of true, false/
    end

    it "should return the 202, and the URL of the repo" do
      post '/api/commands/set-repo-source', {
        "repo"    => { "name" => repo.name },
        "iso-url" => "file:///dev/random"
      }.to_json

      last_response.status.should == 202
      last_response.mime_type.downcase.should == 'application/json'

      data = JSON.parse(last_response.body)
      data.keys.should =~ %w[command id name spec]
      data["id"].should =~ %r"/api/collections/repos/#{repo.name}\Z"
    end

    it "should comform the repo value if given as a string instead of an object" do
      post '/api/commands/set-repo-source', {
        "repo"    => repo.name,
        "iso-url" => "file:///dev/random"
      }.to_json

      last_response.status.should == 202
      last_response.mime_type.downcase.should == 'application/json'

      data = JSON.parse(last_response.body)
      data.keys.should =~ %w[command id name spec]
      data["id"].should =~ %r"/api/collections/repos/#{repo.name}\Z"
    end

    it "should update a repo record in the database" do
      post '/api/commands/set-repo-source', {
        "repo"    => { "name" => repo.name },
        "iso-url" => "file:///dev/random"
      }.to_json

      Repo.find(:name => repo.name).iso_url.should == "file:///dev/random"
    end
  end
end
