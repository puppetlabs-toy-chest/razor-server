require_relative '../spec_helper'
require_relative '../../app'

describe "provisioning API" do
  include Rack::Test::Methods

  def app
    Razor::App
  end

  it "should boot new nodes into the MK" do
    hw_id = "00:11:22:33:44:55"
    get "/svc/boot/#{hw_id}"
    last_response.mime_type.should == "text/plain"
    lines = last_response.body.split(/\s*\n\s*/)
    lines[0].should == "#!ipxe"
    lines[1].should =~ /^kernel/
    lines[2].should =~ /^initrd/
  end

  describe "logging" do
    it "should return 404 logging against nonexisting node" do
      get "/svc/log/432?msg=message&severity=warn"
      last_response.status.should == 404
    end

    it "should store the log message for an existing node" do
      node = Node.create(:hw_id => "00:11:22:33:44:55")

      get "/svc/log/#{node.id}?msg=message&severity=warn"
      last_response.status.should == 204
      log = Node[node.id].log
      log.size.should == 1
      log[0]["msg"].should == "message"
      log[0]["severity"].should == "warn"
    end
  end

  describe "node checkin" do
    hw_id = "00:11:22:33:44:55"

    it "should return 400 for non-json requests" do
      header 'Content-Type', 'text/plain'
      post "/svc/checkin/#{hw_id}", "{}"
      last_response.status.should == 400
    end

    it "should return 400 for malformed JSON" do
      header 'Content-Type', 'application/json'
      post "/svc/checkin/#{hw_id}", "{}}"
      last_response.status.should == 400
    end

    it "should return 400 for JSON without facts" do
      header 'Content-Type', 'application/json'
      post "/svc/checkin/#{hw_id}", { :stuff => 1 }.to_json
      last_response.status.should == 400
    end

    it "should return a none action for a new node" do
      header 'Content-Type', 'application/json'
      body = { :facts => { :hostname => "example" }}.to_json
      post "/svc/checkin/#{hw_id}", body
      last_response.status.should == 200
      last_response.mime_type.should == 'application/json'
      last_response.json.should == { "action" => "none" }
    end
  end
end
