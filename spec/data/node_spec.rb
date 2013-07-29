require_relative "../spec_helper"

describe Razor::Data::Node do

  let (:policy) { make_policy }

  let (:node) { Node.create(:hw_id => "deadbeef") }

  it "lookup should find node by HW id" do
    mac = "00:11:22:33:44:55"
    nc = Node.create(:hw_id => mac)
    nl = Node.lookup(mac)
    nl.should == nc
    nl.id.should_not be_nil
  end

  it "log_append stores messages" do
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

  describe "hostname" do
    it "raises NodeNotBoundError when no policy is bound" do
      expect {
        node.hostname
      }.to raise_error(Razor::Data::NodeNotBoundError)
    end

    it "is set from the policy's hostname_pattern when bound" do
      node.bind(policy)
      node.hostname.should == policy.hostname_pattern.gsub(/%n/, node.id.to_s)
    end
  end

  describe "root_password" do
    it "raises NodeNotBoundError when no policy is bound" do
      expect {
        node.root_password
      }.to raise_error(Razor::Data::NodeNotBoundError)
    end

    it "returns the policy's root_password when bound" do
      node.bind(policy)
      node.root_password.should == policy.root_password
    end
  end

  describe "domainname" do
    it "raises NodeNotBoundError when no policy is bound" do
      expect {
        node.domainname
      }.to raise_error(Razor::Data::NodeNotBoundError)
    end

    it "returns the policy's root_password when bound" do
      node.bind(policy)
      node.domainname.should == policy.domainname
    end
  end


  describe "binding on checkin" do
    hw_id = "00:11:22:33:44:55"

    let (:tag) {
      Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
    }
    let (:node) {
      Node.create(:hw_id => hw_id, :facts => { "f1" => "a" })
    }

    it "should bind to a policy when there is a match" do
      policy = make_policy(:sort_order => 20)
      policy.add_tag(tag)
      policy.save

      Node.checkin({ "hw_id" => hw_id, "facts" => { "f1" => "a" }})

      node = Node.lookup(hw_id)
      node.policy.should == policy
    end

    describe "of a bound node" do
      let (:image) { make_image }

      def make_tagged_policy(sort_order)
        policy = make_policy(:name => "p#{sort_order}",
                             :image => image,
                             :sort_order => sort_order)
        policy.add_tag(tag)
        policy.save
        policy
      end

      it "should not change when policies change" do
        # Setup
        policy20 = make_tagged_policy(20)
        Policy.bind(node)
        node.policy.should == policy20

        # Change the policies
        policy10 = make_tagged_policy(10)
        Node.checkin("hw_id" => node.hw_id, "facts" => node.facts)
        node.reload
        node.policy.should == policy20
      end

      it "should not change when node facts change" do
        node.facts = { "f2" => "a" }
        random_policy = make_policy(:name => "random", :image => image)
        node.bind(random_policy)
        node.save

        policy20 = make_tagged_policy(20)
        Node.checkin("hw_id" => node.hw_id, "facts" => { "f1" => "a" })
        node.reload
        node.tags.should == [ tag ]
        node.policy.should == random_policy
      end
    end
  end
end
