# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::Validation do
  it "should fail if included into a class" do
    expect { Class.new.send('include', Razor::Validation) }.
      to raise_error('Razor::Validation should extend classes, not be included in them')
  end

  context "as part of a class" do
    subject(:c) { Class.new.send('extend', Razor::Validation) }

    it "should have an empty set of validations" do
      c.__validations.should == {}
    end

    it "should do nothing if asked to validate a command without a schema" do
      c.validate!('example-command', {})
    end

    it "should fail if validation is not given a block" do
      expect { c.validate(:example_command) }.
        to raise_error ArgumentError, /block not supplied/
    end

    it "should register a validation if a valid one is supplied" do
      c.validate('test') {}
      c.__validations.should have_key('test')
    end

    it "should invoke a defined validation" do
      Razor.config['auth.enabled'] = false # or we explode!

      c.validate('test') { attr 'fail', required: true }
      expect { c.validate!('test', {}) }.
        to raise_error(/required attribute fail is missing/)
    end
  end
end

describe Razor::ValidationFailure do
  it "should be a TypeError" do
    Razor::ValidationFailure.should be <= TypeError
  end

  it "should default to 422" do
    Razor::ValidationFailure.new('hello').status.should == 422
  end

  it "should allow overrides of status" do
    Razor::ValidationFailure.new('hello', 714).status.should == 714
  end
end
