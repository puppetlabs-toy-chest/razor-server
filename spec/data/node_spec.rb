require_relative "../spec_helper"

describe Razor::Data::Node do
  before(:each) do
    use_task_fixtures
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

    it "should ignore empty and whitespace-only values" do
      info = canonicalize("uuid" => "", "serial" => "  ", "asset" => "  \t \n ")
      info.should == []
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
    describe "raises an ArgumentError" do
      it "when no match criteria are provided" do
        expect { Node.lookup({}) }.to raise_error(ArgumentError)
      end

      it "when none of the configured match criteria are provided" do
        Razor.config['match_nodes_on'] = ['serial', 'uuid']
        hw_hash = { "mac" => ["00-11-22-33-44-55"], "asset" => "abcd" }
        Fabricate(:node, :hw_hash => hw_hash)
        expect { Node.lookup(hw_hash) }.to raise_error(ArgumentError)
      end
    end

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
      nl.id.should == nc.id
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

    it "should disregard hw_info entries not mentioned in match_nodes_on" do
      hw1 = { "serial" => "1", "asset" => "no asset tag" }
      hw2 = { "serial" => "2", "asset" => "no asset tag" }
      Razor.config['match_nodes_on'] = ['serial', 'mac', 'uuid']
      n1 = Fabricate(:node, :hw_hash => hw1)
      n2 = Fabricate(:node, :hw_hash => hw2)

      n1.should_not == n2
      Node.lookup(hw1).should == n1
      Node.lookup(hw2).should == n2
    end

    it "should update hw_info when it changes" do
      hw_hash = { "mac" => ["00-11-22-33-44-55"], "asset" => "abcd" }
      n1 = Node.lookup(hw_hash)
      n1.should_not be_nil

      hw_hash = { "net0" => "de-ad-be-ef-00-00", "asset" => "abcd" }
      n2 = Node.lookup(hw_hash)
      n2.id.should == n1.id
      n2.hw_info.should == [ "asset=abcd", "mac=de-ad-be-ef-00-00" ]
    end

    it "should complain if hardware is moved between known nodes" do
      hw1 = { "net0" => "01:01", "net1" => "01:02" }
      hw2 = { "net0" => "02:01" }
      n1 = Node.lookup(hw1)
      n2 = Node.lookup(hw2)
      n1.id.should_not == n2.id
      # Move the second NIC from n1 to n2
      hw2["net1"] = hw1.delete("net1")
      expect {
        Node.lookup(hw2)
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
      policy = Fabricate(:policy, :rule_number => 20)
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
      policy = Fabricate(:policy, :rule_number => 20)
      policy.add_tag(tag)
      policy.save

      expect do
        node = Node.lookup("net0" => hw_id)
        node.checkin("facts" => { "f1" => "a" })
      end.to raise_error Razor::Matcher::RuleEvaluationError

      node = Node.lookup("net0" => hw_id)
      node.log[0]["severity"].should == "error"
      node.log[0]["msg"].should =~ /typo/
      node.policy.should be_nil
    end

    describe "of a bound node" do
      let (:repo) { Fabricate(:repo) }

      def make_tagged_policy(sort_order)
        policy = Fabricate(:policy,
          :name => "p#{sort_order}",
          :repo => repo,
          :rule_number => sort_order)
        policy.add_tag(tag)
        policy.save
        policy
      end

      it "should not change when policies change" do
        # Setup
        policy20 = make_tagged_policy(20)
        node.match_and_bind
        node.policy.should == policy20

        # Change the policies
        policy10 = make_tagged_policy(10)
        node.checkin("facts" => node.facts)
        node.reload
        node.policy.should == policy20
      end

      it "should not change when node facts change" do
        node.facts = { "f2" => "a" }
        random_policy = Fabricate(:policy, :name => "random", :repo => repo)
        node.bind(random_policy)
        node.save

        policy20 = make_tagged_policy(20)
        node.checkin("facts" => { "f1" => "a" })
        node.reload
        node.tags.should be_empty
        node.policy.should == random_policy
      end

      it "should not change when a tag changes" do
        policy20 = make_tagged_policy(20)
        node.match_and_bind
        node.policy.should == policy20

        # Make the tag not match the node anymore
        tag.rule = ["=", ["fact", "f1"], "b"]
        tag.save
        tag.match?(node).should be_false

        node.checkin("facts" => { "f1" => "a" })
        node.reload
        # node.tags reflects the tags that applied when the node was bound
        node.tags.should == [ tag ]
        node.policy.should == policy20
      end
    end
  end

  describe "checkin handles blacklisted facts" do
    before(:each) do
      Razor.config["facts.blacklist"] = [ "a", "/b[0-9]+/"]
    end

    let (:node) {
      Node.create(:hw_info => ["serial=42"], :facts => { "f1" => "a" })
    }

    ["a", "b17"].each do |k|
      it "(suppresses #{k})" do
        node.checkin("facts" => { k => "1" })
        node.facts.should == {}
      end
    end

    ["a1", "b", "blue", "x"].each do |k|
      it "(does not suppress #{k})" do
        node.checkin("facts" => { k => "1" })
        node.facts.should == { k => "1" }
      end
    end
  end

  describe "last_checkin timestamp" do
    before(:each) do
      Timecop.freeze
    end

    after { Timecop.return }

    it "should be nil when node is created" do
      node = Fabricate(:node)
      node.last_checkin.should be_nil
    end

    it "should not be set by lookup" do
      node = Node.lookup("serial" => "1234")
      node.last_checkin.should be_nil
    end

    describe "on checkin" do
      let (:body) { { "facts" => { "f1" => "1" } } }

      let (:node) do
        n = Fabricate(:node)
        n.checkin(body)
        n
      end

      it "is set" do
        node.last_checkin.should_not be_nil
      end

      it "is updated when facts change" do
        last = node.last_checkin
        Timecop.travel(10)
        body["facts"]["f1"] = "2"

        node.checkin(body)
        node.last_checkin.should > last
      end

      it "is updated when facts do not change" do
        last = node.last_checkin
        Timecop.travel(10)

        node.checkin(body)
        node.last_checkin.should > last
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

  context "IPMI" do
    context "validation" do
      it "should work with only hostname set" do
        # expect this to raise no errors
        node.update(
          :ipmi_hostname => Faker::Internet.ip_v4_address,
          :ipmi_username => nil,
          :ipmi_password => nil)
      end

      it "should work with implicit null username and password" do
        # expect this to raise no errors
        node.update(:ipmi_hostname => Faker::Internet.ip_v4_address)
      end

      it "should accept an IPv4 address for hostname" do
        node.update(:ipmi_hostname => Faker::Internet.ip_v4_address)
      end

      it "should accept a hostname for address" do
        node.update(:ipmi_hostname => Faker::Internet.domain_name)
      end

      it "should work with hostname and username" do
        # expect this to raise no errors
        node.update(
          :ipmi_hostname => Faker::Internet.ip_v4_address,
          :ipmi_username => Faker::Internet.user_name,
          :ipmi_password => nil)
      end

      it "should work with hostname and password" do
        # expect this to raise no errors
        node.update(
          :ipmi_hostname => Faker::Internet.ip_v4_address,
          :ipmi_username => nil,
          :ipmi_password => Faker::Internet.password[0..19])
      end

      it "should work with hostname, username, and password" do
        # expect this to raise no errors
        node.update(
          :ipmi_hostname => Faker::Internet.ip_v4_address,
          :ipmi_username => Faker::Internet.user_name,
          :ipmi_password => Faker::Internet.password[0..19])
      end

      it "should fail with no hostname, but username" do
        expect {
        node.update(
          :ipmi_hostname => nil,
          :ipmi_username => Faker::Internet.user_name,
          :ipmi_password => nil)
        }.to raise_error Sequel::ValidationFailed, /also set an IPMI hostname/
      end

      it "should fail with no hostname, but password" do
        expect {
        node.update(
          :ipmi_hostname => nil,
          :ipmi_username => nil,
          :ipmi_password => Faker::Internet.password[0..19])
        }.to raise_error Sequel::ValidationFailed, /also set an IPMI hostname/
      end

      it "should fail with no hostname, but username, and password" do
        expect {
        node.update(
          :ipmi_hostname => nil,
          :ipmi_username => Faker::Internet.user_name,
          :ipmi_password => Faker::Internet.password[0..19])
        }.to raise_error Sequel::ValidationFailed, /also set an IPMI hostname/
      end
    end

    describe "last_known_power_state" do
      ['on', 'off', nil].each do |value|
        it "should update the timestamp when the power state is set to #{value.inspect}" do
          Timecop.freeze do
            # Make sure that we are not mis-detecting a previously set value
            # on create or something like that as a pass.
            Razor::Data::Node[:id => node.id].
              last_power_state_update_at.should be_nil

            node.update(:last_known_power_state => value).save

            Razor::Data::Node[:id => node.id].
              last_power_state_update_at.should == Time.now()
          end
        end
      end
    end

    describe "update_power_state!" do
      include TorqueBox::Injectors

      before :each do
        node.update(:ipmi_hostname => Faker::Internet.domain_name).save
      end

      let :prehistory do Time.at(-446061360) end
      let :thefuture  do Time.at(1445480880) end
      let :queue      do fetch('/queues/razor/sequel-instance-messages') end


      # @todo danielp 2013-12-05: this stubs the IPMI on? question, which is
      # kinda tied to implementation.  The alternative would be to stub out
      # run, or the power state query mechanism, both of which are about as
      # tied to implementation, so I don't feel too bad about this...

      %w{on off}.each do |value|
        it "should update the power state if the machine is #{value}" do
          Razor::IPMI.stub(:on?).and_return(value == 'on')

          Timecop.freeze(prehistory) do
            node.last_known_power_state.should be_nil
            node.last_power_state_update_at.should be_nil

            node.update_power_state!

            node.last_known_power_state.should == value
            node.last_power_state_update_at.should == prehistory
          end
        end
      end

      it "should update the power state if the same answer is gotten twice" do
        Razor::IPMI.stub(:on?).and_return(true)

        Timecop.freeze(prehistory) do
          node.last_known_power_state.should be_nil
          node.last_power_state_update_at.should be_nil

          node.update_power_state!

          node.last_known_power_state.should == 'on'
          node.last_power_state_update_at.should == prehistory

          Timecop.freeze(thefuture) do
            node.update_power_state!
            node.last_known_power_state.should == 'on'
            node.last_power_state_update_at.should == thefuture
          end
        end
      end

      it "should update the power state to unknown and reraise if an IPMI error occurs" do
        Razor::IPMI.stub(:on?).and_return(true)

        Timecop.freeze(prehistory) do
          node.last_known_power_state.should be_nil
          node.last_power_state_update_at.should be_nil

          node.update_power_state!

          node.last_known_power_state.should == 'on'
          node.last_power_state_update_at.should == prehistory

          Timecop.freeze(thefuture) do
            exception = Razor::IPMI::IPMIError(node, 'power_state', 'fake failure mode')
            Razor::IPMI.stub(:on?).and_raise(exception)

            expect {
              node.update_power_state!
            }.to raise_error exception.class, exception.message

            node.last_known_power_state.should be_nil
            node.last_power_state_update_at.should == thefuture
          end
        end
      end

      it "should not update the power state if a non-IPMI error occurs" do
        Razor::IPMI.stub(:on?).and_return(true)

        Timecop.freeze(prehistory) do
          node.last_known_power_state.should be_nil
          node.last_power_state_update_at.should be_nil

          node.update_power_state!

          node.last_known_power_state.should == 'on'
          node.last_power_state_update_at.should == prehistory

          Timecop.freeze(thefuture) do
            exception = RuntimeError.new('this is your banana flavoured friend')
            Razor::IPMI.stub(:on?).and_raise(exception)

            expect {
              node.update_power_state!
            }.to raise_error exception.class, exception.message

            node.last_known_power_state.should == 'on'
            node.last_power_state_update_at.should == prehistory
          end
        end
      end

      it "should queue nothing else if desired power state is null" do
        Razor::IPMI.stub(:on?).and_return(true, false)

        # First, it is on...
        node.update_power_state!
        queue.should be_empty

        # ...then it is off...
        node.update_power_state!
        queue.should be_empty
      end

      it "should queue nothing if desired is off and actual is off" do
        Razor::IPMI.stub(:on?).and_return(false)
        node.set(:desired_power_state => 'off').save
        node.update_power_state!
        queue.should be_empty
      end

      it "should queue nothing if desired is on and actual is on" do
        Razor::IPMI.stub(:on?).and_return(true)
        node.set(:desired_power_state => 'on').save
        node.update_power_state!
        queue.should be_empty
      end

      it "should queue turning off if desired is off and actual is on" do
        Razor::IPMI.stub(:on?).and_return(true)
        node.set(:desired_power_state => 'off').save

        expect {
          node.update_power_state!
        }.to have_published(
          'class'     => node.class.name,
          'instance'  => node.pk_hash,
          'message'   => 'off',
          'arguments' => []
        ).on(queue)
      end

      it "should queue turning on if desired is on and actual is off" do
        Razor::IPMI.stub(:on?).and_return(false)
        node.set(:desired_power_state => 'on').save

        expect {
          node.update_power_state!
        }.to have_published(
          'class'     => node.class.name,
          'instance'  => node.pk_hash,
          'message'   => 'on',
          'arguments' => []
        ).on(queue)
      end

      it "should queue turning on twice if actual remains off when checked again" do
        Razor::IPMI.stub(:on?).and_return(false)
        node.set(:desired_power_state => 'on').save

        expect {
          node.update_power_state!
        }.to have_published(
          'class'     => node.class.name,
          'instance'  => node.pk_hash,
          'message'   => 'on',
          'arguments' => []
        ).on(queue)

        expect {
          node.update_power_state!
        }.to have_published(
          'class'     => node.class.name,
          'instance'  => node.pk_hash,
          'message'   => 'on',
          'arguments' => []
        ).on(queue)
      end
    end
  end

  context "installed state" do
    it "is empty for new nodes" do
      node.installed.should be_nil
      node.installed_at.should be_nil
    end

    it "stays empty when stage_done is called with a name != 'finished'" do
      Node.stage_done(node.id, 'some stage').should be_true

      node.reload
      node.installed.should be_nil
      node.installed_at.should be_nil
    end

    it "gets set when stage_done is called with name == 'finished'" do
      node.bind(policy)
      node.save

      Node.stage_done(node.id, 'finished').should be_true
      node.reload

      node.installed.should == policy.name
      node.installed_at.should_not be_nil
    end

    it "is reset when an installed node is rebound" do
      node = Fabricate(:node, :installed => 'old_stuff',
                              :installed_at => DateTime.now)
      node.bind(policy)
      node.installed.should be_nil
      node.installed_at.should be_nil
    end
  end

  context "search" do
    before(:each) do
      @node1 = Fabricate(:node, :hostname => "host1.example.com")
      @node2 = Fabricate(:node, :hostname => "host2.example.com")
    end

    it "should look for hostnames as a regexp" do
      Node.search("hostname" => "host1.*").all.should == [ @node1 ]
      Node.search("hostname" => "host.*").all.should =~ [ @node1, @node2 ]
    end

    it "should look for MACs case-insensitively" do
      mac = @node1.hw_hash["mac"].first
      Node.search("mac" => mac).all.should == [ @node1 ]
      Node.search("mac" => mac.upcase).all.should == [ @node1 ]
      Node.search("mac" => mac.upcase).all.should == [ @node1 ]
      Node.search("mac" => mac.upcase.gsub("-", ":")).all.should == [ @node1 ]
    end

    it "should look for asset tags" do
      asset = @node1.hw_hash["asset"]
      Node.search("asset" => asset).all.should == [ @node1 ]
      Node.search("asset" => asset.upcase).all.should == [ @node1 ]
    end
  end
end
