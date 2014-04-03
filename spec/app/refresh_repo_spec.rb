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
      post '/api/commands/refresh-repo', {"cats" => "> dogs"}.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end

    it "should fail if an extra key is given, if otherwise good" do
      post '/api/commands/refresh-repo', {
        "name"      => "magicos",
        "banana"    => "> orange",
      }.to_json
      last_response.status.should == 422
      last_response.mime_type.downcase.should == 'application/json'
    end
  end
end
