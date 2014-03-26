# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::ArrayAttribute do
  context "initialize" do
    subject(:attr) do described_class end

    context "index" do
      it "should fail if two hashes are passed" do
        expect { attr.new({}, {type: String}) }.
          to raise_error TypeError, /index must be an integer or a range of integers/
      end

      it "should work if only one argument, a hash, is given" do
        attr.new(type: String)
      end

      it "should work if nil is given explicitly as the index" do
        attr.new(nil, type: String)
      end

      it "should work if an integer >= 0 is given as the index" do
        attr.new(0, type: String)
        attr.new(1, type: String)
      end

      it "Should fail if an integer < 0 is given as the index" do
        expect { attr.new(-1, type: String) }.
          to raise_error ArgumentError, /index -1 must be at or above zero/
      end

      it "should work if a range is given as the index" do
        attr.new(0..1, type: String)
      end

      it "should fail if the range starts < 0" do
        expect { attr.new(-1..1) }.
          to raise_error ArgumentError, /index must start at or above zero/
      end

      it "should fail if the range includes nothing" do
        expect { attr.new(5..1) }.
          to raise_error ArgumentError, /index does not contain any values!/
        expect { attr.new(1...1) }.
          to raise_error ArgumentError, /index does not contain any values!/
      end

      it "should fail if an array is given" do
        expect { attr.new([1,2]) }.
          to raise_error TypeError, /index must be an integer or a range of integers/
      end
    end

    it "should fail if checks are an explicit nil" do
      expect { attr.new(0, nil) }.
        to raise_error TypeError, /must be followed by a hash/
    end

    it "should fail if checks are an array" do
      expect { attr.new(0, []) }.
        to raise_error TypeError, /must be followed by a hash/
    end
  end
end
