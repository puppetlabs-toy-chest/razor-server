require_relative "../spec_helper"

describe Razor::Data::Node do
  before(:each) do
    use_installer_fixtures
  end

  let (:policy) { Fabricate(:policy) }

  let (:node) { Fabricate(:node) }

  context "canonicalize_hw_info" do
    def canonicalize(hw_info)
      Node.canonicalize_hw_info(hw_info)
    end

    it "should rename netX to mac" do
      canonicalize("net0" => "1", "net1" => "2").should == ["mac=1", "mac=2"]
    end

    it "should order MACs case insensitively" do
      canonicalize("net0" => "B", "net1" => "a").should == ["mac=a", "mac=b"]
    end

    it "should sort entries by keys" do
      canonicalize("uuid" => "1", "serial" => "2", "asset" => "asset").should ==
        ["asset=asset", "serial=2", "uuid=1"]
    end
  end

  context "hw_hash=" do
    it "canonicalizes a hash" do
      n = Node.new(:hw_hash => { "mac" => ["B", "a"], "serial" => "1" })
      n.hw_info.should == ["mac=a", "mac=b", "serial=1"]
    end
  end

  context "find_by_name" do
    it "finds a node" do
      node = Fabricate(:node)
      Node.find_by_name(node.name).should == node
    end

    ["node42", "hello there", ""].each do |name|
      it "returns nil for nonexistant node '#{name}'" do
        Node.find_by_name(name).should be_nil
      end
    end
  end

  context "lookup" do
    it "should find node by hw_info" do
      hw_hash = { "mac" => ["00-11-22-33-44-55"], "asset" => "abcd" }
      nc = Fabricate(:node, :hw_hash => hw_hash)
      nl = Node.lookup(hw_hash)
      nl.should == nc
      nl.id.should_not be_nil
    end

    it "should find node by partial hw_info" do
      hw_hash = { "mac" => ["00-11-22-33-44-55"], "asset" => "abcd" }
      nc = Fabricate(:node, :hw_hash => hw_hash)
      nl = Node.lookup("asset" => "ABCD")
      nl.should == nc
      nl.id.should_not be_nil
    end

    it "should create node when no match exists" do
      hw_hash = { "mac" => ["00-11-22-33-44-55"], "asset" => "abcd" }
      nl = Node.lookup(hw_hash)
      nl.id.should_not be_nil
      Node[nl.id].should_not be_nil
      nl.hw_hash.should == hw_hash
    end

    it "should raise DuplicateNodeError if two nodes have overlapping hw_info" do
      hw1 = { "serial" => "1", "asset" => "asset" }
      hw2 = { "serial" => "1", "uuid" => "u1" }
      n1 = Fabricate(:node, :hw_hash => hw1)
      n2 = Fabricate(:node, :hw_hash => hw2)
      expect {
        Node.lookup(hw1)
      }.to raise_error(Razor::Data::DuplicateNodeError)
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
      Node.create(:hw_info => ["mac=#{hw_id}"], :facts => { "f1" => "a" })
    }

    it "should bind to a policy when there is a match" do
      policy = Fabricate(:policy, :line_number => 20)
      policy.add_tag(tag)
      policy.save

      node = Node.lookup("net0" => hw_id)
      node.checkin("facts" => { "f1" => "a" })
      node.modified?.should be_false

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
        node = Node.lookup("net0" => hw_id)
        node.checkin("facts" => { "f1" => "a" })
      end.to raise_error Razor::Matcher::RuleEvaluationError

      node = Node.lookup("net0" => hw_id)
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
        node.checkin("facts" => node.facts)
        node.reload
        node.policy.should == policy20
      end

      it "should not change when node facts change" do
        node.facts = { "f2" => "a" }
        random_policy = Fabricate(:policy, :name => "random", :image => image)
        node.bind(random_policy)
        node.save

        policy20 = make_tagged_policy(20)
        node.checkin("facts" => { "f1" => "a" })
        node.reload
        node.tags.should == [ tag ]
        node.policy.should == random_policy
      end
    end
  end

  describe "freeze" do
    it "works for an existing node" do
      n = Fabricate(:node)
      n.save
      n.freeze
      n.name.should_not be_nil
      expect { n.hostname = "host" }.to raise_error /frozen/
      expect { n.facts = { "f2" => "y" } }.to raise_error /frozen/
      expect { n.save }.to raise_error /frozen/
    end
  end
end
