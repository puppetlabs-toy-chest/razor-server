require_relative "../spec_helper"

describe Razor::Data::Node do
  it "lookup should find node by HW id" do
    mac = "00:11:22:33:44:55"
    nc = Node.create(:hw_id => mac)
    nl = Node.lookup(mac)
    nl.should == nc
    nl.id.should_not be_nil
  end

  it "log_append stores messages" do
    node = Node.create(:hw_id => "deadbeef")
    node.log_append(:msg => "M1")
    node.log_append(:msg => "M2", :severity => :error)
    node.save

    n = Node[node.id]
    n.log.size.should == 2
    n.log[0]["msg"].should == "M1"
    n.log[0]["severity"].should == "info"
    n.log[0]["timestamp"].should_not be_nil
    n.log[1]["msg"].should == "M2"
    n.log[1]["severity"].should == "error"
    n.log[1]["timestamp"].should_not be_nil
  end
end
