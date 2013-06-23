require_relative 'spec_helper'

describe Razor::Installer do
  Installer = Razor::Installer

  before(:each) do
    use_installer_fixtures
  end

  describe "find" do
    it "finds an existing installer" do
      inst = Installer.find("someos")
      inst.should_not be_nil
      inst.name.should == "some_os"
    end

    it "searches multiple paths in order" do
      Razor::Config.config["installer_path"] +=
        ":" + File::join(FIXTURES_PATH, "other_installers")
      inst = Installer.find("shadowed")
      inst.should_not be_nil
      inst.name.should == "shadow"

      inst = Installer.find("other")
      inst.should_not be_nil
      inst.name.should == "other"
    end

    it "raises InstallerNotFoundError for nonexistent installer" do
      expect {
        Installer.find("no such installer")
      }.to raise_error(Razor::InstallerNotFoundError)
    end
  end

  describe "view_path" do
    let(:inst) { Installer.find("someos") }

    it "finds version-specific template" do
      inst.view_path("specific").should == File::join(INST_PATH, "some_os/3")
    end

    it "finds common template" do
      inst.view_path("example").should == File::join(INST_PATH, "common")
    end

    it "raises TemplateNotFoundError for unknown template" do
      expect {
        inst.view_path("nonexistent template")
      }.to raise_error(Razor::TemplateNotFoundError)
    end

    it "work when the template name ends in .erb" do
      inst.view_path("specific.erb").should ==
        File::join(INST_PATH, "some_os/3")
    end
  end
end
