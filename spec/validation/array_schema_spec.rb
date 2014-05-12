# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::ArraySchema do
  subject :schema do Razor::Validation::ArraySchema.new("test") end

  context "initialize" do
    context "object" do
      it "requires a block" do
        expect { schema.object }.
            to raise_error ArgumentError, /an object must have a block to define it/
      end
    end

    context "element" do
      it "allows both element and elements" do
        schema.should respond_to :elements
        schema.should respond_to :element
      end
    end
  end

  context "validate!" do
    it "should not validate non-array objects" do
      expect { schema.validate!({}, 'path') }.
        to raise_error Razor::ValidationFailure, /path should be an array, but got object/
    end

    it "should perform element checks" do
      schema.element  0, type: String
      schema.elements 1, type: Integer

      expect { schema.validate!(['string', 'string'], 'path')}.
          to raise_error Razor::ValidationFailure, 'path[1] should be a number, but was actually a string'

      schema.validate!(['string'], 'path')
      schema.validate!(['string', 0], 'path')
    end
  end

  context "to_s" do
    subject :text do schema.to_s end

    it "should document that this is an array" do
      should =~ /This value must be an array/
    end

    it "should document the requirements for all elements" do
      schema.elements type: String
      should =~ /All elements must be of type string./
    end

    it "should document 0..10 correctly" do
      schema.elements 0..10, references: Razor::Data::Tag
      should =~ /Elements from 0 to 10 must match the name of an existing tag./
    end

    it "should document 2..4 correctly" do
      schema.elements 2..4, references: Razor::Data::Tag
      should =~ /Elements from 2 to 4 must match the name of an existing tag./
    end

    it "should document an infinite series correctly" do
      schema.elements 2..Float::INFINITY, references: Razor::Data::Tag
      should =~ /Elements from 2 onward must match the name of an existing tag./
    end
  end
end
