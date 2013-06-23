require_relative '../spec_helper'
require_relative '../../app'

describe "provisioning API" do
  include Rack::Test::Methods

  def app
    Razor::App
  end

  before(:each) do
    use_installer_fixtures
  end

  it "should boot new nodes into the MK" do
    hw_id = "00:11:22:33:44:55"
    get "/svc/boot/#{hw_id}"
    assert_booting("Microkernel")
  end

  describe "booting known nodes" do
    before(:each) do
      @node = Node.create(:hw_id => "00:11:22:33:44:55")
    end

    it "without policy should boot the microkernel" do
      get "/svc/boot/#{@node.hw_id}"
      assert_booting("Microkernel")
    end

    it "with policy repeatedly should boot the installer kernels" do
      pl = Policy.create(:name => "p1", :enabled => true,
                         :image => make_image, :installer_name => "someos")
      @node.bind(pl)
      @node.save
      get "/svc/boot/#{@node.hw_id}"
      assert_booting("Boot SomeOS 3")

      get "/svc/boot/#{@node.hw_id}"
      assert_booting("Boot SomeOS 3 again")

      get "/svc/boot/#{@node.hw_id}"
      assert_booting("Boot local")
    end
  end

  describe "fetching a template" do
    before(:each) do
      @node = Node.create(:hw_id => "00:11:22:33:44:55")
      @policy = Policy.create(:name => "p1", :enabled => true,
                              :image => make_image, :installer_name => "someos")
      @node.bind(@policy)
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
      assert_url_response("/svc/store/#{@node.id}", "v1" => "42", "v2" => "3")
    end

    it "should interpolate node_url" do
      get "/svc/file/#{@node.id}/node_url"
      assert_url_response("/api/nodes/#{@node.id}")
    end

    it "should provide config" do
      get "/svc/file/#{@node.id}/config"
      assert_template_body("Razor::Util::TemplateConfig")
    end

    it "should raise an error when accessing prohibited config keys" do
      get "/svc/file/#{@node.id}/config_prohibited"
      last_response.status.should == 500
    end

    it "should provide access to node and installer" do
      get "/svc/file/#{@node.id}/node_installer_vars"
      assert_template_body("some_os/someos")
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
