require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  shared_examples "an image creation endpoint" do |api_path|
    before :each do
      header 'content-type', 'application/json'
    end

    it "should reject bad JSON" do
      post api_path, '{"json": "not really..."'
      last_response.status.should == 415
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    [
      "foo", 100, 100.1, -100, true, false, [], ["name", "a"]
    ].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post api_path, input
        last_response.status.should == 415
      end
    end

    it "should fail with only bad key present in input" do
      post api_path, {"cats" => "> dogs"}.to_json
      last_response.status.should == 400
      # @todo danielp 2013-06-26: should do something to assert we got a good
      # error message or messages out of the system; see comments in app.rb
      # for details about why that is delayed.
    end

    it "should fail if only the name is given" do
      post api_path, {"name" => "magicos"}.to_json
      last_response.status.should == 400
    end

    it "should fail if only the image_url is given" do
      post api_path, {"image_url" => "file:///dev/null"}.to_json
      last_response.status.should == 400
    end

    it "should fail if an extra key is given, if otherwise good" do
      post api_path, {
        "name"      => "magicos",
        "image-url" => "file:///dev/null",
        "banana"    => "> orange",
      }.to_json
      last_response.status.should == 400
    end

    it "should return the 202, and the URL of the image" do
      post api_path, {
        "name" => "magicos",
        "image-url" => "file:///dev/null"
      }.to_json

      last_response.status.should == 202

      data = JSON.parse(last_response.body)
      data.keys.should =~ %w[class href properties rel]
      data["properties"].keys.should =~ ["name"]
      data["href"].should =~ %r'/api/collections/images/magicos\Z'
    end

    it "should create an image record in the database" do
      post api_path, {
        "name" => "magicos",
        "image-url" => "file:///dev/null"
      }.to_json

      Image.find(:name => "magicos").should be_an_instance_of Image
    end
  end

  context "/api/commands/create-image" do
    it_should_behave_like "an image creation endpoint", "/api/commands/create-image"
  end

  context "/api/collections/images" do
    it_should_behave_like "an image creation endpoint", "/api/collections/images"
  end
end
