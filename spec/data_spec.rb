# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::Data do
  describe Razor::Data::ClassMethods do
    subject('cm') do
      Class.new.send('extend', Razor::Data::ClassMethods)
    end

    it "should translate simple words nicely" do
      stub_const('Razor::Data::Test', cm)
      cm.friendly_name.should == 'test'
    end

    it "should translate complex words nicely" do
      stub_const('Razor::Data::TestWithWords', cm)
      cm.friendly_name.should == 'test with words'
    end
  end
end
