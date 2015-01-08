# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::Data::Event do
  describe "entry" do
    it "should require that entry is present" do
      expect { Razor::Data::Event.new.save }.
          to raise_error(Sequel::ValidationFailed, 'entry is not present')
    end

    it "should accept and save an empty hash" do
      Razor::Data::Event.new(
          :entry => {}
      ).save
    end

    it "should round-trip a rich entry" do
      entry = {"one" => 1, "two" => 2.0, "three" => ['a', {'b'=>'b'}, ['c']]}
      Fabricate(:node).log_append(entry)

      # Round-trip to avoid symbol vs. string key comparison issues.
      entry = JSON.parse(Razor::Data::Event.last.entry.to_json)
      entry.should == entry
    end
  end
end