# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::ArrayAttribute do
  def attr
    Razor::Validation::ArrayAttribute
  end

  context "initialize" do
    subject(:attr) do described_class end

    context "index" do
      it "should fail if two hashes are passed" do
        expect { attr.new({}, {type: String}) }.
            to raise_error TypeError, /index must be an integer or a range of integers/
      end

      it "should work if nil is given explicitly as the index" do
        attr.new(nil, {type: String})
      end

      it "should work if an integer >= 0 is given as the index" do
        attr.new(0, {type: String})
        attr.new(1, {type: String})
      end

      it "Should fail if an integer < 0 is given as the index" do
        expect { attr.new(-1, {type: String}) }.
            to raise_error ArgumentError, /index -1 must be at or above zero/
      end

      it "should work if a range is given as the index" do
        attr.new(0..1, {type: String})
      end

      it "should fail if the range starts < 0" do
        expect { attr.new(-1..1, {}) }.
            to raise_error ArgumentError, /index must start at or above zero/
      end

      it "should fail if the range includes nothing" do
        expect { attr.new(5..1, {}) }.
            to raise_error ArgumentError, /index does not contain any values!/
        expect { attr.new(1...1, {}) }.
            to raise_error ArgumentError, /index does not contain any values!/
      end

      it "should fail if an array is given" do
        expect { attr.new([1,2], {}) }.
            to raise_error TypeError, /index must be an integer or a range of integers/
      end
    end

    it "should work if checks are an explicit nil" do
      attr.new(0, nil)
    end

    it "should fail if checks are an array" do
      expect { attr.new(0, []) }.
          to raise_error TypeError, /must be followed by a hash/
    end
  end

  context "validate!" do
    subject(:attr) { Razor::Validation::ArrayAttribute.new(0, {}) }

    it "should fail if value's key is blank" do
      attr.type(Hash)
      expect { attr.validate!({'' => 'abc'}, 'some_path', 0) }.
        to raise_error(/blank hash key not allowed/)
    end

    it "should fail if wrong datatype specified" do
      attr.type(String)
      expect { attr.validate!({'' => 'abc'}, 'some_path', 0) }.
          to raise_error(/some_path\[0\] should be a string, but was actually a object/)
    end

    it "should allow strings" do
      attr.type(String)
      attr.validate!("string", 'some_path', 0)
    end
  end

  context "references" do
    let :node do Fabricate(:node) end
    let :attr do Razor::Validation::ArrayAttribute.new(nil, {}) end

    before :each do
      attr.references(Razor::Data::Node)
    end

    it "should fail if the referenced instance does not exist" do
      expect { attr.validate!((node.id + 12).to_s, 'some_path', 0) }.
          to raise_error(/some_path\[0\] must be the name of an existing node, but is '#{node.id + 12}'/)
    end

    it "should succeed with a valid reference" do
      attr.validate!(node.name, 'some_path', 0)
    end
  end

end
