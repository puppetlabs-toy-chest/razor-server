require_relative '../spec_helper'
require_relative '../../app'

describe "create installer command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-installer" do
    before :each do
      header 'content-type', 'application/json'
    end

    let(:installer_hash) do
      { :name => "installer",
        :os => "SomeOS",
        :templates => { "name" => "erb template" },
        :boot_seq => { 1 => "boot_install", "default" => "boot_local" } }
    end

    def create_installer(input = nil)
      input ||= installer_hash.to_json
      post '/api/commands/create-installer', input
    end

    it "should reject bad JSON" do
      create_installer '{"json": "not really..."'
      last_response.status.should == 415
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    [
      "foo", 100, 100.1, -100, true, false, [], ["name", "a"]
    ].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        create_installer input
        last_response.status.should == 415
      end
    end

    # Spot check that validation errors are surfaced as 400
    it "should fail if name is missing" do
      installer_hash.delete(:name)
      create_installer
      last_response.status.should == 400
    end

    it "should fail if os is missing" do
      installer_hash.delete(:os)
      create_installer
      last_response.status.should == 400
    end

    it "should fail if boot_seq hash has keys that are strings != 'default'" do
      installer_hash[:boot_seq]["sundays"] = "local"
      create_installer
      last_response.status.should == 400
    end

    it "should fail if templates is not a hash" do
      installer_hash[:templates] = ["stuff"]
      create_installer
      last_response.status.should == 400
    end

    # Successful creation
    it "should return 202, and the URL of the installer" do
      create_installer
      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[id name spec]

      last_response.json["id"].should =~ %r'/api/collections/installers/installer\Z'
    end

    it "should create an repo record in the database" do
      create_installer

      Razor::Data::Installer[:name => installer_hash[:name]].should be_an_instance_of Razor::Data::Installer
    end
  end
end
