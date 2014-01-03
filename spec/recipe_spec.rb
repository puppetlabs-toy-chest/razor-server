require_relative 'spec_helper'

describe Razor::Recipe do
  Recipe = Razor::Recipe

  before(:each) do
    use_recipe_fixtures
  end

  describe "find" do
    it "finds an existing recipe" do
      inst = Recipe.find("some_os")
      inst.should_not be_nil
      inst.name.should == "some_os"
    end

    it "searches multiple paths in order" do
      Razor.config["recipe_path"] += ":" + File::join(FIXTURES_PATH, "other_recipes")
      inst = Recipe.find("shadowed")
      inst.should_not be_nil
      inst.name.should == "shadowed"

      inst = Recipe.find("other")
      inst.should_not be_nil
      inst.name.should == "other"
    end

    it "raises RecipeNotFoundError for nonexistent recipe" do
      expect {
        Recipe.find("no such recipe")
      }.to raise_error(Razor::RecipeNotFoundError)
    end

    it "supports recipe inheritance" do
      inst = Recipe.find("some_os_derived")
      inst.description.should == "Derived Some OS Installer"
      # We leave the label in the derived recipe unset on purpose
      # so we get to see the base label
      inst.label.should == "Some OS, version 3"
    end

    it "raises RecipeInvalidError if os_version is missing" do
      expect {
        Recipe.find("no_os_version")
      }.to raise_error(Razor::RecipeInvalidError)
    end
  end


  describe "find for DB and file recipes" do
    it "finds them in the database" do
      inst = Razor::Data::Recipe.create(:name => 'dbinst',
                                           :os => 'SomeOS',
                                           :os_version => '6')
      Razor::Recipe.find('dbinst').should == inst
    end

    it "prefers recipes in the file system" do
      Razor::Data::Recipe.create(:name => 'some_os',
                                    :os => 'SomeOS',
                                    :os_version => '6')
      Recipe.find("some_os").should be_an_instance_of Razor::Recipe
    end
  end

  describe "find_template" do
    let(:inst) { Recipe.find("some_os") }
    let(:derived) { Recipe.find("some_os_derived") }

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

    it "prefers templates for the derived recipe" do
      derived.find_template("specific.erb").should ==
        [:specific, { :views => File::join(INST_PATH, "some_os_derived")}]
    end

    it "uses templates for the base recipe if the derived one doesn't match" do
      derived.find_template("template.erb").should ==
        [:template, { :views => File::join(INST_PATH, "some_os/3") }]
    end
  end

  describe "boot_template" do
    it "uses the boot template with the right seq" do
      inst = Recipe.find("some_os")
      node = Razor::Data::Node.new(:hw_info => ["mac=deadbeef"],
                                   :boot_count => 0)
      ["boot_install", "boot_again", "boot_local", "boot_local"].each do |t|
        node.boot_count += 1
        inst.boot_template(node).should == t
      end
    end
  end
end
