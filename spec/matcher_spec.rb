require_relative 'spec_helper'

describe Razor::Matcher do
  Matcher = Razor::Matcher

  describe "#new" do
    it { expect {Matcher.new({}).to raise_error TypeError} }
    it { expect {Matcher.new("rule").to raise_error TypeError} }
  end

  describe "::unserialize" do
    context "with invalid JSON data" do
      it { expect {Matcher.unserialize({}).to raise_error } }
      it { expect {Matcher.unserialize(1).to raise_error } }
      it { expect {Matcher.unserialize('{"rule": []').to raise_error } }
    end

    context "with extra keys" do
      subject(:m) { Matcher.unserialize('{"rule":[],"extra":1}') }
      it { expect {m}.to raise_error }
    end

    context "with missing keys" do
      subject(:m) { Matcher.unserialize('{}') }
      it { expect {m}.to raise_error }
    end

    context "with the correct values" do
      subject(:m) { Matcher.unserialize('{"rule":["=",1,1]}') }
      it { m.rule.should == ["=", 1, 1] }
    end

    it "should have the same rule as a serialized matcher" do
      m = Matcher.new(["=",["fact", "fifteen"], 15])
      Matcher.unserialize(m.serialize).rule.should == m.rule
    end
  end

  def match(*rule)
    facts = {}
    facts = rule.pop if rule.last.is_a?(Hash)
    m = Matcher.new(rule)
    m.match?("facts" => facts)
  end

  describe "functions" do
    it "and should behave" do
      match("and", true, true).should == true
      match("and", true, true, false, true).should == false
    end

    it "or should behave" do
      match("or", true, true).should == true
      match("or", true, true, false, true).should == true
      match("or", false, false, false).should == false
    end

    it "fact should behave" do
      match("fact", "f1", { "f1" => "true" }).should == true
      match("fact", "f1", { "f1" => false  }).should == false
    end

    it "fact should raise if fact not found and one argument given" do
      expect do
        match("fact", "f2", { "f1" => "true" })
      end.to raise_error Razor::Matcher::RuleEvaluationError
    end

    it "fact should return the default if fact not found" do
      match("fact", "f1", false, { "f1" => true }).should == true
      match("fact", "f2", false, { "f1" => true }).should == false
    end

    it "eq should behave" do
      match("=", 1, 1).should == true
      match("=", 1, 2).should == false
      match("=", "abc", "abc").should == true
      match("=", "abc", "abcd").should == false
    end

    it "neq should behave" do
      match("!=", 1, 1).should == false
      match("!=", 1, 2).should == true
      match("!=", "abc", "abc").should == false
      match("!=", "abc", "abcd").should == true
    end

    it "in should behave" do
      match("in", "a", "b", "c", "a").should == true
      match("in", "x", "b", "c", "a").should == false
    end
  end

  describe "#valid?" do
    it "should require String-, Numeric-, Nil-, or Boolean-typed arguments" do
      Matcher.new(["eq", ["fact","now"], Time.now]).should_not be_valid
    end

    it "should require booleans for 'and' function" do
      Matcher.new(["and", true, false]).should be_valid
      Matcher.new(["and", 1, true]).should_not be_valid
      Matcher.new(["and", "six", false]).should_not be_valid
    end

    it "should require booleans for 'or' function" do
      Matcher.new(["or", false, true]).should be_valid
      Matcher.new(["or", "version", true]).should_not be_valid
      Matcher.new(["or", 5.4, 3]).should_not be_valid
    end

    it "should allow all types for '=' function" do
      Matcher.new(["=", true, false]).should be_valid
      Matcher.new(["eq", 1, ["=", 5, "ten"]]).should be_valid
      Matcher.new(["eq", 6.3, 3]).should be_valid
    end

    it "should allow all types for '!=' function" do
      Matcher.new(["=", 3, 10]).should be_valid
      Matcher.new(["eq", 'one', ["=", 6.7, "t"]]).should be_valid
      Matcher.new(["eq", 'C', 3, 'P', 'O']).should be_valid
    end

    it "should allow all types for 'in' function" do
      Matcher.new(["in",true, ["in", 1, "two"], false]).should be_valid
      Matcher.new(["in", 0, 1, 3.6, 10e20]).should be_valid
    end

    it "should require strings for argument 1 of the 'fact' function" do
      Matcher.new(["=",["fact","exists"], true]).should be_valid
      Matcher.new(["!=", ["fact", "one"], 0]).should be_valid
      Matcher.new(["=", ["fact", 5], "five"]).should_not be_valid
      Matcher.new(["and", ["fact", 4.458], true]).should_not be_valid
    end

    it "should allow all types for argument 2 of the 'fact' function" do
      Matcher.new(["=",["fact","exists", "default"], true]).should be_valid
      Matcher.new(["=",["fact","not", 1], true]).should be_valid
      Matcher.new(["=",["fact","maybe", nil], true]).should be_valid
    end

    it "should require that top-level functions return booleans" do
      Matcher.new(["=",true, false]).should be_valid
      Matcher.new(["!=",true, false]).should be_valid
      Matcher.new(["or",true, false]).should be_valid
      Matcher.new(["and",true, false]).should be_valid
      Matcher.new(["in",true, false]).should be_valid
      Matcher.new(["fact","three"]).should_not be_valid
    end

    it "should validate nested functions" do
      Matcher.new(
        ["and",
          ["or",
            ["in",3, 1, 2, 3, 4, 5, 6],
            ["=", "five", 5]
          ],
          ["=", ["fact", "true"], true]
        ]).should be_valid
      Matcher.new(
        ["in", 3,
          ["fact", "ten"],
          ["or",                    # This 'or' should be invalid, since it requires
            ["fact", "fifteen"],    # boolean arguments, and 'facts' returns multiple
            ["fact", "seven"]       # types.
          ]
        ]).should_not be_valid
    end

    it "should reject unknown functions" do
      Matcher.new(["be",true, false]).should_not be_valid
      Matcher.new(["=",["ten"], 10]).should_not be_valid
      Matcher.new(["===",true, false]).should_not be_valid
      Matcher.new(["+",1, 1]).should_not be_valid
      Matcher.new(["-",true, false]).should_not be_valid
    end
  end

  it "should handle nested evaluation" do
    match("and", ["=", ["fact", "f1"], 42],
                 ["!=", ["fact", "f2"], 43],
          { "f1" => 42, "f2" => 42 }).should == true
    match("and", ["in", ["fact", "f1"], 41, 42, 43, 44],
                 ["!=", ["fact", "f2"], 42],
          { "f1" => 42, "f2" => 42 }).should == false
  end
end
