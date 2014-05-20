# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "provisioning API" do
  include Rack::Test::Methods

  def app
    Razor::App
  end

  before(:each) do
    use_task_fixtures
    authorize 'fred', 'dead'
  end

  let (:policy) do
    Fabricate(:policy, task_name: 'some_os')
  end

  it "should boot new nodes into the MK" do
    get "/svc/boot?net0=00:11:22:33:44:55"
    assert_booting("Microkernel")
  end

  it "should log an error if more than one node matches the hw_info" do
    n1 = Fabricate(:node, :hw_info => ["serial=s1", "asset=a1"])
    n2 = Fabricate(:node, :hw_info => ["serial=s2", "asset=a1"])
    get "/svc/boot?asset=a1"
    last_response.status.should == 400
    [n1, n2].each do |n|
      n.reload
      entry = n.log.last
      entry.should_not be_nil
      entry['severity'].should == 'error'
      entry['event'].should == 'boot'
      entry['error'].should == 'duplicate_node'
    end
  end

  it "should tolerate empty and extraneous parameters in /svc/boot" do
    get "/svc/boot?serial=1234&net0=&net1=&asset=&nic_max=4"
    assert_booting("Microkernel")
  end

  describe "/svc/boot complains with a 400" do
    it "when no parameters are passed" do
      get "/svc/boot"
      last_response.status.should == 400
    end

    it "when none of the parameters are in match_nodes_on" do
      Razor.config['match_nodes_on'] = ['mac']
      get "/svc/boot?serial=X1"
      last_response.status.should == 400
    end
  end

  describe "booting known nodes" do
    before(:each) do
      @node = Fabricate(:node)
      @mac = @node.hw_hash["mac"].first
    end

    it "without policy should boot the microkernel" do
      get "/svc/boot?net0=#{@mac}"
      assert_booting("Microkernel")
      @node.reload
      @node.log.last["event"].should == "boot"
      @node.log.last["task"].should == "microkernel"
      @node.log.last["template"].should == "boot"
      @node.log.last["repo"].should == "microkernel"
    end

    describe "booting repeatedly with policy" do
      before(:each) do
        @node.bind(policy)
        @node.save
        @mac = @node.hw_hash["mac"].first
      end

      it "without calling stage_done boots the same template" do
        get "/svc/boot?net0=#{@mac}"
        assert_booting("Boot SomeOS 3")

        get "/svc/boot?net0=#{@mac}"
        assert_booting("Boot SomeOS 3")

        get "/svc/boot?net0=#{@mac}"
        assert_booting("Boot SomeOS 3")
      end

      it "with calling stage_done progresses through the boot sequence" do
        get "/svc/stage-done/#{@node.id}"
        last_response.status.should == 204

        get "/svc/boot?net0=#{@mac}"
        assert_booting("Boot SomeOS 3 again")

        get "/svc/stage-done/#{@node.id}"
        last_response.status.should == 204

        get "/svc/boot?net0=#{@mac}"
        assert_booting("Boot local")
      end

      it "marks node installed when name is 'finished'" do
        @node.installed.should be_nil

        get "/svc/stage-done/#{@node.id}?name=finished"
        last_response.status.should == 204

        @node = Node[@node.id]
        @node.installed.should == policy.name
        @node.installed_at.should_not be_nil
      end
    end


    describe "dhcp_mac" do
      dhcp_mac = "11:22:33:44:55:66"

      it "should be nil when not provided" do
        header 'Content-Type', 'application/json'
        get "/svc/boot?net0=#{@mac}"

        last_response.status.should == 200
        node = Node.lookup("net0" => @mac)
        node.dhcp_mac.should be_nil
      end

      it "should be stored when given in the checkin data" do
        header 'Content-Type', 'application/json'
        get "/svc/boot?net0=#{@mac}&dhcp_mac=#{dhcp_mac}"

        last_response.status.should == 200
        node = Node.lookup("net0" => @mac)
        node.dhcp_mac.should == dhcp_mac
      end

      it "should stick around when booting again without dhcp_mac" do
        @node.dhcp_mac = dhcp_mac
        @node.save

        header 'Content-Type', 'application/json'
        get "/svc/boot?net0=#{@mac}"

        last_response.status.should == 200
        node = Node.lookup("net0" => @mac)
        node.dhcp_mac.should == dhcp_mac
      end
    end
  end

  describe "fetching a template" do
    before(:each) do
      @node = Fabricate(:node)
      @node.bind(policy)
      @node.save
    end

    it "should find the template" do
      get "/svc/file/#{@node.id}/template"
      assert_template_body("# Template\n")
    end

    it "should interpolate file_url" do
      get "/svc/file/#{@node.id}/file_url"
      assert_url_response("/svc/file/#{@node.id}/some_file")
    end

    it "should interpolate log_url" do
      get "/svc/file/#{@node.id}/log_url"
      assert_url_response("/svc/log/#{@node.id}",
                          "msg" => "message", "severity" => "error")
    end

    it "should interpolate store_url" do
      get "/svc/file/#{@node.id}/store_url"
      assert_url_response("/svc/store_metadata/#{@node.id}",
                          "v1" => "42", "v2" => "3")
    end

    it "should interpolate node_url" do
      get "/svc/file/#{@node.id}/node_url"
      assert_url_response("/api/nodes/#{@node.id}")
    end

    describe "repo_url" do
      ["/foo", "foo"].each do |path|
        it "should work with repo.iso_url and path #{path}" do
          policy.repo.iso_url.should_not be_nil
          get "/svc/file/#{@node.id}/repo_url?path=#{path}"
          assert_url_response("/svc/repo/#{URI::escape(policy.repo.name)}/foo")
        end
      end

      ["http://example.org/repo", "http://example.org/repo/"].each do |url|
        ["/foo", "foo"].each do |path|
          it "should work with repo.url #{url} and path #{path}" do
            policy.repo.iso_url = nil
            policy.repo.url = url
            policy.repo.save

            get "/svc/file/#{@node.id}/repo_url?path=#{path}"
            assert_url_response("/repo/foo")
            last_response.body.should == "http://example.org/repo/foo"
          end
        end
      end
    end

    it "should interpolate store_metadata_url" do
      get "/svc/file/#{@node.id}/store_metadata_url"
      assert_url_response("/svc/store_metadata/#{@node.id}",
                          "a" => "v1", "b" => "v2",
                          "remove" => ["x", "y", "z"])
    end

    it "should provide config" do
      get "/svc/file/#{@node.id}/config"
      assert_template_body("Razor::Util::TemplateConfig")
    end

    it "should raise an error when accessing prohibited config keys" do
      get "/svc/file/#{@node.id}/config_prohibited"
      last_response.status.should == 500
    end

    it "should provide access to node and task" do
      get "/svc/file/#{@node.id}/node_installer_vars"
      assert_template_body("some_os/some_os")
    end

    it "should return 404 for nonexistent template" do
      get "/svc/file/#{@node.id}/no_such_template_exists"
      last_response.status.should == 404
    end
  end

  describe "logging" do
    it "should return 404 logging against nonexisting node" do
      get "/svc/log/432?msg=message&severity=warn"
      last_response.status.should == 404
    end

    it "should store the log message for an existing node" do
      node = Fabricate(:node)

      get "/svc/log/#{node.id}?msg=message&severity=warn"
      last_response.status.should == 204
      log = Node[node.id].log
      log.size.should == 1
      log[0]["msg"].should == "message"
      log[0]["severity"].should == "warn"
    end
  end

  describe "storing node metadata" do
    before(:each) do
      @node = Fabricate(:node)
    end

    it "should store a value" do
      get "/svc/store_metadata/#{@node.id}?a=v1"
      last_response.status.should == 204

      node = Node[@node.id]
      node.metadata.should == { "a" => "v1" }
    end

    it "should update a value" do
      @node.metadata["a"] = "old"
      @node.save

      get "/svc/store_metadata/#{@node.id}?a=v1"
      last_response.status.should == 204

      node = Node[@node.id]
      node.metadata.should == { "a" => "v1" }
    end

    it "should remove a value" do
      @node.metadata["x"] = "old"
      @node.save

      get "/svc/store_metadata/#{@node.id}?remove[]=x"
      last_response.status.should == 204

      node = Node[@node.id]
      node.metadata.should == { }
    end

    it "should update and remove values"do
      @node.metadata["x"] = "old"
      @node.save

      get "/svc/store_metadata/#{@node.id}?remove[]=x&a=v1"
      last_response.status.should == 204

      node = Node[@node.id]
      node.metadata.should == { "a" => "v1" }
    end
  end

  describe "node checkin" do
    hw_id = "001122334455"

    it "should return 400 for non-json requests" do
      header 'Content-Type', 'text/plain'
      post "/svc/checkin/42", "{}"
      last_response.status.should == 400
    end

    it "should return 400 for malformed JSON" do
      header 'Content-Type', 'application/json'
      post "/svc/checkin/42", "{}}"
      last_response.status.should == 400
    end

    it "should return 400 for JSON without facts" do
      header 'Content-Type', 'application/json'
      post "/svc/checkin/42", { :stuff => 1 }.to_json
      last_response.status.should == 400
    end

    it "should return 404 for a new node" do
      header 'Content-Type', 'application/json'
      body = { :facts => { :hostname => "example" } }.to_json
      post "/svc/checkin/42", body
      last_response.status.should == 404
    end

    it "should return 200 if tag evaluation fails and log an error" do
      node = Fabricate(:node_with_facts)
      # This will cause a RuleEvaluationError since there is no 'none' fact
      # in the checkin
      tag = Fabricate(:tag, :rule => ["=", ["fact", "none"], "1"])

      header 'Content-Type', 'application/json'
      body = { :facts => { :architecture => "i386" } }.to_json
      post "/svc/checkin/#{node.id}", body

      last_response.status.should == 200
      last_response.json.should == { "action" => "none" }

      node.reload
      node.log.last["severity"].should == "error"
    end

    it "should update the hw_info" do
      Razor.config['match_nodes_on'] = ['mac', 'serial']
      Razor.config['facts.match_on'] = ['/f\d+/']

      node = Fabricate(:node, :hw_info => [ 'serial=1234' ])

      header 'Content-Type', 'application/json'
      body = { "facts" => { "serialnumber" => "1234",
                            "f1" => "a",
                            "g1" => "b",
                            "macaddress_eth0" => "de:ad:be:ef:00:01",
                            "macaddress_eth1" => "de:ad:be:ef:00:02"} }.to_json
      post "/svc/checkin/#{node.id}", body

      last_response.status.should == 200
      last_response.json.should == { "action" => "none" }

      node.reload
      node.hw_info.should == ["fact_f1=a",
                              "mac=de-ad-be-ef-00-01", "mac=de-ad-be-ef-00-02",
                              "serial=1234"]
    end

    describe "with multiple nodes" do
      before(:each) do
        Razor.config['match_nodes_on'] = ['serial']
        Razor.config['facts.match_on'] = ['/f\d+/']
      end

      it "should merge nodes into one that is registered" do
        n1 = Fabricate(:node, :hw_info => [ 'serial=1', 'fact_f1=a' ],
                       :facts => { "f1" => "a" })
        n2 = Fabricate(:node, :hw_info => [ 'serial=2' ])
        n3 = Fabricate(:node, :hw_info => [ 'serial=2' ])

        header 'Content-Type', 'application/json'
        body = { "facts" => { "serialnumber" => "2",
                              "f1" => "a"} }.to_json
        post "/svc/checkin/#{n2.id}", body

        last_response.status.should == 200
        last_response.json.should == { "action" => "none" }

        n1.reload
        n1.hw_info.should == ["fact_f1=a", "serial=2"]
        Node[n2.id].should be_nil
        Node[n3.id].should be_nil
      end

      it "should merge unregistered nodes into one of them" do
        nodes = [Fabricate(:node, :hw_info => [ 'serial=1', 'fact_f1=a' ]),
                 Fabricate(:node, :hw_info => [ 'serial=2' ]),
                 Fabricate(:node, :hw_info => [ 'serial=2' ])]

        header 'Content-Type', 'application/json'
        body = { "facts" => { "serialnumber" => "2",
                              "f1" => "a"} }.to_json
        post "/svc/checkin/#{nodes[1].id}", body

        last_response.status.should == 200
        last_response.json.should == { "action" => "none" }

        new_nodes = nodes.map { |n| Node[n.id] }.compact

        new_nodes.size.should == 1
        new_nodes[0].registered?.should be_true
      end

      it "should fail when multiple registered nodes match the checkin for an unregistered one" do
        nodes = [Fabricate(:node, :hw_info => [ 'serial=1', 'fact_f1=a' ],
                           :facts => { 'f1' => 'a' }),
                 Fabricate(:node, :hw_info => [ 'serial=2' ],
                           :facts => { 'g1' => 'x' }),
                 Fabricate(:node, :hw_info => [ 'serial=2' ])]

        header 'Content-Type', 'application/json'
        body = { "facts" => { "serialnumber" => "2",
                              "f1" => "a"} }.to_json
        post "/svc/checkin/#{nodes[2].id}", body

        last_response.status.should == 400

        new_nodes = nodes.map { |n| Node[n.id] }.compact
        new_nodes.size.should == 3
      end

      it "should succeed when multiple registered nodes match the checkin for a registered one" do
        # This is a side-effect of only calling Node.register on
        # unregistered nodes. It may (or may not) be desirable to always
        # call register on such nodes in the future; for a real node,
        # Node.lookup, called from /svc/boot would have raised an error
        # already and the node would have never gotten this far
        nodes = [Fabricate(:node, :hw_info => [ 'serial=1', 'fact_f1=a' ],
                           :facts => { 'f1' => 'a' }),
                 Fabricate(:node, :hw_info => [ 'serial=2' ],
                           :facts => { 'g1' => 'x' }),
                 Fabricate(:node, :hw_info => [ 'serial=2' ])]

        header 'Content-Type', 'application/json'
        body = { "facts" => { "serialnumber" => "2",
                              "f1" => "a"} }.to_json
        post "/svc/checkin/#{nodes[1].id}", body

        last_response.status.should == 200

        new_nodes = nodes.map { |n| Node[n.id] }.compact
        new_nodes.size.should == 3
      end
    end
  end

  def assert_booting(msg)
    last_response.mime_type.should == "text/plain"
    last_response.body.should == "# #{msg}\n"
  end

  def assert_template_body(body)
    last_response.mime_type.should == "text/plain"
    last_response.status.should == 200
    last_response.body.should == body
  end

  def assert_url_response(path, params = {})
    last_response.mime_type.should == "text/plain"
    last_response.status.should == 200
    uri = URI::parse(last_response.body)
    uri.path.should == path
    Rack::Utils::parse_nested_query(uri.query).should == params
  end
end
