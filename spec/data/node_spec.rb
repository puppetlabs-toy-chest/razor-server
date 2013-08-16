require_relative "../spec_helper"

describe Razor::Data::Node do

  before(:each) do
    use_installer_fixtures
  end

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
    hw_id = "00:11:22:33:44:55"

    let (:tag) {
      Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
    }
    let (:node) {
      Node.create(:hw_id => hw_id, :facts => { "f1" => "a" })
    }

    it "should bind to a policy when there is a match" do
      policy = make_policy(:line_number => 20)
      policy.add_tag(tag)
      policy.save

      Node.checkin({ "hw_id" => hw_id, "facts" => { "f1" => "a" }})

      node = Node.lookup(hw_id)
      node.policy.should == policy
    end

    it "should refuse to bind to a policy if any tag raises an error" do
      bad_tag = Tag.create(:name => "t2", :matcher => Razor::Matcher.new(["=", ["fact", "typo"], "b"]))
      policy = make_policy(:line_number => 20)
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
      let (:image) { make_image }

      def make_tagged_policy(line_number)
        policy = make_policy(:name => "p#{line_number}",
                             :image => image,
                             :line_number => line_number)
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
