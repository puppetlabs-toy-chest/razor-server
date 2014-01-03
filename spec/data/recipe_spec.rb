require_relative '../spec_helper'

describe Razor::Data::Recipe do
  class MockNode
    attr_reader :facts

    def initialize(facts)
      @facts = facts
    end
  end

  before(:each) do
    use_recipe_fixtures
  end

  subject(:recipe) do
    Razor::Data::Recipe.create(
      :name => 'test',
      :os => 'SomeOS',
      :templates => {
         "simple" => "Simple Template",
         "overridden" => "Base"
      },
      :boot_seq => {
         1 => "boot_install",
         2 => "boot_again",
         "default" => "boot_local"
      })
  end

  subject(:derived) do
    recipe  # Must exist for the FK on base
    Razor::Data::Recipe.create(
      :name => 'derived',
      :base => 'test',
      :os => 'SomeOS',
      :templates => {
         "overridden" => "Derived"
      })
  end

  describe "persistence" do
    it "initializes templates and boot_seq to an empty hash" do
      inst = Razor::Data::Recipe.new
      inst.templates.should == {}
      inst.boot_seq.should == {}
    end

    def rejects(attr, value)
      # The simpler recipe[attr] = value leads to obscure errors
      recipe.set_fields({ attr => value }, [attr])
      expect {
        recipe.save
      }.to raise_error(Sequel::ValidationFailed)
    end

    describe "templates" do
      def rejects_templates(value)
        rejects "templates", value
      end

      it "must be a Hash" do
        rejects_templates [ "name" ]
      end

      it "requires keys to be strings" do
        rejects_templates(:name => "Text")
      end

      it "requires values to be strings" do
        rejects_templates("name" => :stuff)
      end
    end

    describe "boot_seq" do
      def rejects_boot_seq(value)
        rejects "boot_seq", value
      end

      it "must be a Hash" do
        rejects_boot_seq [ "boot" ]
      end

      it "allows integer keys and 'default'" do
        recipe.boot_seq = { 1 => "one", 2 => "two", 70 => "seventy",
                               "default" => "default" }
        recipe.save.should be_true
      end

      it "keys can not be symbols" do
        rejects_boot_seq(:name => "boot")
      end

      it "keys can not be string representations of integers" do
        rejects_boot_seq("42" => "boot")
      end

      it "requires values to be strings" do
        rejects_boot_seq("default" => :stuff)
      end
    end
  end

  describe "find_template" do
    it "raises TemplateNotFoundError for nonexistent template" do
      expect {
        recipe.find_template('no such template').should_not be_nil
      }.to raise_error(Razor::TemplateNotFoundError)
    end

    it "returns a template as a string" do
      recipe.find_template('simple').should == ["Simple Template", {}]
    end

    it "finds a template in a base recipe" do
      derived.find_template('simple').should == ["Simple Template", {}]
    end

    it "prefers the template in a derived recipe" do
      derived.find_template('overridden').should == ["Derived", {}]
    end

    it "finds templates in the common dir" do
      derived.find_template('example').should ==
        [:example, { :views => File::join(INST_PATH, "common")}]
    end
  end

  describe "boot_template" do
    it "uses the boot template with the right seq" do
      node = Razor::Data::Node.new(:hw_info => ["mac=deadbeef"],
                                   :boot_count => 0)
      ["boot_install", "boot_again", "boot_local", "boot_local"].each do |t|
        node.boot_count += 1
        recipe.boot_template(node).should == t
      end
    end
  end
end
