require_relative '../spec_helper'

describe Razor::Data::Tag do
  class MockNode
    attr_reader :facts

    def initialize(facts)
      @facts = facts
    end
  end

  it "matches on the right facts" do
    t = Tag.create(:name => "t0",
                   :matcher => Razor::Matcher.new(["in", ["fact", "f1"], "a", "b", "c"]))
    Tag.match(MockNode.new("f1" => "c")).should == [ t ]
    Tag.match(MockNode.new("f1" => "x")).should == []
  end

  context "when rule is nil" do
    subject(:tag) {Tag.create(:name => "t1")}
    it { should be_valid }
  end

  context "when rule is valid" do
    subject(:tag) {Tag.create(:name=>"t2", :matcher => Razor::Matcher.new(["=",["fact","five"], 5]))}
    it { should be_valid }
  end

  context "when rule is not valid" do
    subject(:tag) {Tag.new(:name=>"t2", :matcher => Razor::Matcher.new(["yes","no"]))}
    it { should_not be_valid }
    it { tag.valid?; tag.errors[:matcher].should_not be_empty }
  end
end
