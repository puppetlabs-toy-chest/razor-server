# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::ArraySchema do
  subject(:schema) { Razor::Validation::ArraySchema.new("test") }
  context "initialize" do

    context "object" do
      it "requires a block" do
        expect { schema.object }.
            to raise_error ArgumentError, /an object must have a block to define it/
      end
    end

    context "element" do
      it "allows both element and elements" do
        schema.elements
        schema.element
      end
    end
  end

  context "validate!" do
    it "should not validate non-array objects" do
      expect { schema.validate!({}, 'path') }.
        to raise_error Razor::ValidationFailure, /path should be an array, but got object/
    end

    it "should perform element checks" do
      schema.element(0, {type: String})
      schema.elements(1, {type: Integer})
      expect { schema.validate!(['string', 'string'], 'path')}.
          to raise_error Razor::ValidationFailure, /path\[1\] should be a number, but was actually a string/
      schema.validate!(['string'], 'path')
      schema.validate!(['string', 0], 'path')
    end
  end
end
