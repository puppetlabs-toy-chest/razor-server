# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::HashAttribute do
  def attr
    Razor::Validation::HashAttribute
  end

  context "initialize" do
    it "should fail if the name is not a string" do
      expect { attr.new(:test, {}) }.
        to raise_error(/attribute name must be a string/)
    end

    ['Boom', 'bing bang', 'bro()'].each do |input|
      it "should fail if the name has illegal characters (#{input.inspect})" do
        expect { attr.new(input, {}) }.
          to raise_error(/attribute name is not valid/)
      end
    end

    [[], "required", :required].each do |input|
      it "should fail if checks are not a hash (#{input.inspect})" do
        expect { attr.new('test', input) }.
          to raise_error(/must be followed by a hash/)
      end
    end

    it "should fail if an unknown check is passed alone" do
      expect { attr.new('test', explode: true) }.
        to raise_error(/does not know how to perform a explode check/)
    end

    it "should fail if an unknown check is passed with valid checks" do
      expect { attr.new('test', required: true, explode: true) }.
        to raise_error(/does not know how to perform a explode check/)
    end
  end

  context "validate!" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    it "should fail if the attribute is required but not present" do
      attr.required(true)
      expect { attr.validate!({}) }.
        to raise_error(/required attribute attr is missing/)
    end

    it "should return true if the attribute is not required and not present" do
      attr.required(false)
      attr.validate!({}).should be_true
    end

    it "should fail if it excludes another attribute that is present" do
      attr.exclude('fail')
      expect { attr.validate!('attr' => true, 'fail' => true) }.
        to raise_error(/if attr is present, fail must not be present/)
    end

    [{}, [], 1, 1.1, true, false, nil].each do |input|
      it "should fail if type is specified (String), and not matched (#{input.inspect})" do
        attr.type(String)
        expect { attr.validate!({'attr' => input}) }.
          to raise_error(/attribute attr has wrong type .+ where string was expected/)
      end
    end

    it "should fail if the type is URI, and it has a bad URI passed" do
      attr.type(URI)
      expect { attr.validate!({'attr' => 'http://'}) }.
        to raise_error(/bad URI/)
    end

    context "references" do
      let :node do Fabricate(:node) end
      # Necessary because of the magic in lookups.
      let :attr do Razor::Validation::HashAttribute.new('id', {}) end

      before :each do
        attr.references(Razor::Data::Node)
        attr.required(true)
      end

      it "should fail if the referenced instance does not exist" do
        expect { attr.validate!({'id' => node.id + 12}) }.
          to raise_error(/attribute id must refer to an existing instance/)
      end

      it "should have a 404 status on the error when the instance does not exist" do
        test_code_ran = false

        begin
          attr.validate!({'id' => node.id + 12})
        rescue Razor::ValidationFailure => e
          e.status.should == 404
          test_code_ran = true
        end

        # This is to catch the case where we fail to throw, so don't make the
        # assertion at all, and pass because nothing failed and rspec is "pass
        # unless something fails".
        test_code_ran.should be_true
      end

      it "should succeed if the referenced instance does exist" do
        attr.validate!({'id' => node.id}).should be_true
      end
    end
  end

  context "type" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    ["String", true, false, 1, 1.1, :string].each do |input|
      it "should fail unless the type is a class or module (#{input.inspect})" do
        expect { attr.type(input) }.
          to raise_error(/type checks must be passed a class, module, nil, or an array of the same/)
      end
    end

    [[], {}].each do |input|
      it "should fail if given an empty collection (#{input.inspect})" do
        expect { attr.type(input) }.
          to raise_error(/type checks must be passed some type to check/)
      end
    end
  end

  context "exclude" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    it "should accept a string" do
      expect { attr.exclude('test') }.not_to raise_error
    end

    it "should accept an array of strings" do
      expect { attr.exclude(%w{test fun bang}) }.not_to raise_error
    end

    [:symbol, {:foo => 1}, 1, true, false, nil].each do |input|
      it "should fail if the argument is not a string or array (#{input.inspect})" do
        expect { attr.exclude(input) }.
          to raise_error(/attribute exclusions must be a string, or an array of strings/)
      end
      it "should fail if the argument is an array, and contains a non-string (#{input.inspect}" do
        expect { attr.exclude(['good', input, 'boom']) }.
          to raise_error(/attribute exclusions must be a string, or an array of strings/)
      end
    end
  end

  context "references" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    [[], Object, URI, String].each do |input|
      it "should fail if the argument is not a Sequel::Model #{input.inspect}" do
        expect { attr.references(input) }.
          to raise_error(/attribute references must be a class that respond to find/)
      end
    end

    it "should accept a Sequel::Model derived class" do
      expect { attr.references(Razor::Data::Node) }.not_to raise_error
    end
  end
end
