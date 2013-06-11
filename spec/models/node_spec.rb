require_relative "../spec_helper"

describe Razor::Models::Node do
  Node = Razor::Models::Node

  it "lookup should find node by HW id" do
    mac = "00:11:22:33:44:55"
    nc = Node.create(:hw_id => mac)
    nl = Node.lookup(mac)
    nl.should == nc
    nl.id.should_not be_nil
  end
end
