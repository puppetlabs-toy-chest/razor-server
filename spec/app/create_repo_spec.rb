# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-repo" do
    before :each do
      header 'content-type', 'application/json'
    end

    it "should reject bad JSON" do
      post '/api/commands/create-repo', '{"json": "not really..."'
      last_response.json['error'].should =~ /unable to parse JSON/
      last_response.status.should == 400
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/create-repo', input
        last_response.json['error'].should =~ /unable to parse JSON/
        last_response.status.should == 400
      end
    end

    [[], ["name", "a"]].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/create-repo', input
        last_response.json['error'].should =~ /expected object but got array/
        last_response.status.should == 422
      end
    end

    it "should fail with only bad key present in input" do
      post '/api/commands/create-repo', {"cats" => "> dogs"}.to_json
      last_response.json['error'].should =~ /name is a required attribute, but it is not present/
      last_response.status.should == 422
    end

    it "should fail if iso-url and url are omitted" do
      post '/api/commands/create-repo', {"name" => "magicos", "task" => {"name" => "some_os"}}.to_json
      last_response.json['error'].should =~ /the command requires one out of the iso-url, url attributes to be supplied/
      last_response.status.should == 422
    end

    it "should fail if task is omitted" do
      post '/api/commands/create-repo', {
          "name"      => "magicos",
          "iso-url"   => "file:///dev/null",
          "banana"    => "> orange",
      }.to_json
      last_response.json['error'].should =~ /task is a required attribute, but it is not present/
      last_response.status.should == 422
    end

    it "should fail if task's name is omitted" do
      post '/api/commands/create-repo', {
          "name"      => "magicos",
          "iso-url"   => "file:///dev/null",
          "banana"    => "> orange",
          "task"      => { }
      }.to_json
      last_response.json['error'].should =~ /task\.name is a required attribute, but it is not present/
      last_response.status.should == 422
    end

    it "should fail if an extra key is given, if otherwise good" do
      post '/api/commands/create-repo', {
        "name"      => "magicos",
        "iso-url"   => "file:///dev/null",
        "banana"    => "> orange",
        "task"      => {'name' => "some_os"},
      }.to_json
      last_response.json['error'].should =~ /extra attribute banana was present in the command, but is not allowed/
      last_response.status.should == 422
    end

    it "should return the 202, and the URL of the repo" do
      command 'create-repo', {
        "name" => "magicos",
        "iso-url" => "file:///dev/null",
        "task"    => {'name' => "some_os"},
      }, :status => :pending

      last_response.status.should == 202

      data = last_response.json
      data.keys.should =~ %w[id name spec]
      data["id"].should =~ %r'/api/collections/repos/magicos\Z'
    end

    context "with an existing repo" do
      let :repo do Fabricate(:repo) end

      it "should return 202 if the repo is identical" do
        data = {
          'name'    => repo.name,
          'iso-url' => repo.iso_url,
          'task'    => {'name' => repo.task.name}
        }

        command 'create-repo', data

        last_response.json['name'].should == repo.name
        last_response.status.should == 202
      end

      it "should return 409 if the repo is not identical" do
        data = {
          'name' => repo.name,
          'url'  => repo.iso_url,
          'task' => {'name' => repo.task.name}
        }

        command 'create-repo', data

        last_response.json['error'].should ==
          "The repo #{repo.name} already exists, and the iso_url, url fields do not match"
        last_response.status.should == 409
      end
    end

    it "should create an repo record in the database" do
      command 'create-repo', {
        "name" => "magicos",
        "iso-url" => "file:///dev/null",
        "task"    => {'name' => "some_os"},
      }, :status => :pending

      Repo.find(:name => "magicos").should be_an_instance_of Repo
    end

    it "should conform to allow task-name shortcut" do
      command 'create-repo', {
          "name" => "magicos",
          "iso-url" => "file:///dev/null",
          "task"    => "some_os",
      }, :status => :pending

      Repo.find(:name => "magicos").should be_an_instance_of Repo
    end
  end
end
