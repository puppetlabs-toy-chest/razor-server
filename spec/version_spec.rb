# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::VERSION do
  it "should not include a newline" do
    Razor::VERSION.should_not =~ /\n/
  end
end
