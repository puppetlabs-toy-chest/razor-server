require_relative '../spec_helper'
require_relative '../../app'

describe "create tag command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-tag" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:tag_hash) do
      { :name => "test",
        :rule => ["=", ["fact", "kernel"], "Linux"] }
    end

    def create_tag(input = nil)
      input ||= tag_hash.to_json
      post '/api/commands/create-tag', input
    end

    it "should reject bad JSON" do
      create_tag '{"json": "not really..."'
      last_response.status.should == 415
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    [
     "foo", 100, 100.1, -100, true, false, [], ["name", "a"]
    ].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        create_tag input
        last_response.status.should == 415
      end
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

      Razor::Data::Tag[:name => tag_hash[:name]].should be_an_instance_of Razor::Data::Tag
    end
  end
end
