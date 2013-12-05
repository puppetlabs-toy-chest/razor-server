require_relative 'spec_helper'

describe Razor::Installer do
  Installer = Razor::Installer

  before(:each) do
    use_installer_fixtures
  end

  describe "find" do
    it "finds an existing installer" do
      inst = Installer.find("some_os")
      inst.should_not be_nil
      inst.name.should == "some_os"
    end

    it "searches multiple paths in order" do
      Razor.config["installer_path"] +=
        ":" + File::join(FIXTURES_PATH, "other_installers")
      inst = Installer.find("shadowed")
      inst.should_not be_nil
      inst.name.should == "shadowed"

      inst = Installer.find("other")
      inst.should_not be_nil
      inst.name.should == "other"
    end

    it "raises InstallerNotFoundError for nonexistent installer" do
      expect {
        Installer.find("no such installer")
      }.to raise_error(Razor::InstallerNotFoundError)
    end

    it "supports installer inheritance" do
      inst = Installer.find("some_os_derived")
      inst.description.should == "Derived Some OS Installer"
      # We leave the label in the derived installer unset on purpose
      # so we get to see the base label
      inst.label.should == "Some OS, version 3"
    end

    it "raises InstallerInvalidError if os_version is missing" do
      expect {
        Installer.find("no_os_version")
      }.to raise_error(Razor::InstallerInvalidError)
    end
  end


  describe "find for DB and file installers" do
    it "finds them in the database" do
      inst = Razor::Data::Installer.create(:name => 'dbinst',
                                           :os => 'SomeOS',
                                           :os_version => '6')
      Razor::Installer.find('dbinst').should == inst
    end

    it "prefers installers in the file system" do
      Razor::Data::Installer.create(:name => 'some_os',
                                    :os => 'SomeOS',
                                    :os_version => '6')
      Installer.find("some_os").should be_an_instance_of Razor::Installer
    end
  end

  describe "find_template" do
    let(:inst) { Installer.find("some_os") }
    let(:derived) { Installer.find("some_os_derived") }

    it "finds version-specific template" do
      inst.find_template("specific").should ==
        [:specific, { :views => File::join(INST_PATH, "some_os/3")}]
    end

    it "finds common template" do
      inst.find_template("example").should ==
        [:example, { :views => File::join(INST_PATH, "common")}]
    end

    it "raises TemplateNotFoundError for unknown template" do
      expect {
        inst.find_template("nonexistent template")
      }.to raise_error(Razor::TemplateNotFoundError)
    end

    it "work when the template name ends in .erb" do
      inst.find_template("specific.erb").should ==
        [:specific, { :views => File::join(INST_PATH, "some_os/3") }]
    end

    it "prefers templates for the derived installer" do
      derived.find_template("specific.erb").should ==
        [:specific, { :views => File::join(INST_PATH, "some_os_derived")}]
    end

    it "uses templates for the base installer if the derived one doesn't match" do
      derived.find_template("template.erb").should ==
        [:template, { :views => File::join(INST_PATH, "some_os/3") }]
    end
  end

  describe "boot_template" do
    it "uses the boot template with the right seq" do
      inst = Installer.find("some_os")
      node = Razor::Data::Node.new(:hw_info => ["mac=deadbeef"],
                                   :boot_count => 0)
      ["boot_install", "boot_again", "boot_local", "boot_local"].each do |t|
        node.boot_count += 1
        inst.boot_template(node).should == t
      end
    end
  end
end
