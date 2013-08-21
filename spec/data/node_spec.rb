require_relative "../spec_helper"

describe Razor::Data::Node do
  before(:each) do
    use_installer_fixtures
  end

  let (:policy) { Fabricate(:policy) }

  let (:node) { Node.create(:hw_id => "deadbeef") }

  context "canonicalize_hw_id" do
    {
      '00:0c:29:56:a5:35' => '000c2956a535',
      '00:0C:29:56:A5:35' => '000c2956a535',
      '00:0c:29:3f:68:c3____' => '000c293f68c3',
      '00:0C:29:3f:68:C3____' => '000c293f68c3',
      '00:0C:29:B5:1F:D1_00:0C:29:3f:68:C3_00:0c:29:56:a5:35__' =>
          '000c29b51fd1000c293f68c3000c2956a535'
    }.each do |have, want|
      it "should canonicalize #{have.inspect} to #{want.inspect}" do
        Node.canonicalize_hw_id(have).should == want
      end
    end
  end

  context "lookup" do
    it "should find node by HW id" do
      mac = "001122334455"
      nc = Node.create(:hw_id => mac)
      nl = Node.lookup(mac)
      nl.should == nc
      nl.id.should_not be_nil
    end

    it "should find the correct node for several mac inputs" do
      # hand calculated the canonical version...
      node = Fabricate(:node, :hw_id => '5254000d97f0')
      Node.lookup('52:54:00:0d:97:f0____').should == node
      Node.lookup('5254000d97f0').should == node
    end
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
    it "is null when no policy is bound" do
      node.hostname.should be_nil
    end

    it "is set from the policy's hostname_pattern when bound" do
      policy.hostname_pattern = "host${id}.example.org"
      policy.save
      node.bind(policy)
      node.hostname.should == "host#{node.id}.example.org"
    end
  end

  describe "root_password" do
    it "is null when no policy is bound" do
      node.root_password.should be_nil
    end

    it "returns the policy's root_password when bound" do
      node.bind(policy)
      node.root_password.should == policy.root_password
    end
  end

  describe "shortname" do
    it "is null when no policy is bound" do
      node.domainname.should be_nil
    end

    it "is the short hostname when bound" do
      node.bind(policy)
      node.shortname.should_not =~ /\./
    end
  end


  describe "binding on checkin" do
    hw_id = "001122334455"

    let (:tag) {
      Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
    }
    let (:node) {
      Node.create(:hw_id => hw_id, :facts => { "f1" => "a" })
    }

    it "should bind to a policy when there is a match" do
      policy = Fabricate(:policy, :line_number => 20)
      policy.add_tag(tag)
      policy.save

      Node.checkin({ "hw_id" => hw_id, "facts" => { "f1" => "a" }})

      node = Node.lookup(hw_id)
      node.policy.should == policy
      node.log.last["action"].should == "reboot"
      node.log.last["policy"].should == policy.name
    end

    it "should refuse to bind to a policy if any tag raises an error" do
      bad_tag = Tag.create(:name => "t2", :matcher => Razor::Matcher.new(["=", ["fact", "typo"], "b"]))
      policy = Fabricate(:policy, :line_number => 20)
      policy.add_tag(tag)
      policy.save

      expect do
        Node.checkin({ "hw_id" => hw_id, "facts" => { "f1" => "a" }})
      end.to raise_error Razor::Matcher::RuleEvaluationError

      node = Node.lookup(hw_id)
      node.log[0]["severity"].should == "error"
      node.log[0]["msg"].should =~ /tags/
      node.policy.should be_nil
    end

    describe "of a bound node" do
      let (:image) { Fabricate(:image) }

      def make_tagged_policy(sort_order)
        policy = Fabricate(:policy,
          :name => "p#{sort_order}",
          :image => image,
          :line_number => sort_order)
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
        random_policy = Fabricate(:policy, :name => "random", :image => image)
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
