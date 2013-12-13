require_relative '../spec_helper'
require_relative '../../app'

# This should eventually be done by a command line tool resp. the server
# when adding an installer. For now, we use it to sanity check the
# file-based installers that we have
describe "stock installer" do
  include Rack::Test::Methods

  INSTALLER_PATH = File::join(Razor.root, "installers")
  INSTALLER_NAMES = Dir::glob(File::join(INSTALLER_PATH, "*.yaml")).map do |path|
    File::basename(path, ".yaml")
  end

  def app
    Razor::App
  end

  before :each do
    authorize 'fred', 'dead'
  end

  INSTALLER_NAMES.each do |name|
    describe name do
      before(:each) do
        Razor.config["installer_path"] = INSTALLER_PATH

        @node = Fabricate(:node, :hw_info => ["mac=001122334455"])
        policy = Fabricate(:policy, :installer_name => name)
        @node.bind(policy)
        @node.save
      end

      let(:installer) { Razor::Installer.find(name) }

      it "can be loaded" do
        installer.should_not be_nil
      end

      Dir::glob(File::join(INSTALLER_PATH, name, "**/*.erb")).map do |fn|
        File::basename(fn, ".erb")
      end.each do |templ|
        it "can load the #{templ} template" do
          get "/svc/file/#{@node.id}/#{templ}"
          last_response.status.should == 200
          last_response.body.should_not be_empty
        end
      end
    end
  end
end
