# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::ArrayAttribute do
  def attr
    Razor::Validation::ArrayAttribute
  end

  context "validate!" do
    subject(:attr) { Razor::Validation::ArrayAttribute.new(0) }

    it "should fail if value's key is blank" do
      attr.type(Hash)
      expect { attr.validate!({'' => 'abc'}, 0) }.
        to raise_error(/blank hash key/)
    end
  end

end
