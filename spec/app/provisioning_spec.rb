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
end
