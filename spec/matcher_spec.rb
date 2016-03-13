# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::Matcher do
  Matcher = Razor::Matcher
  RuleEvaluationError = Razor::Matcher::RuleEvaluationError

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

  def matches(*rule)
    facts = {}
    facts = rule.pop if rule.last.is_a?(Hash)
    m = Matcher.new(rule)
    m.match?("facts" => facts)
  end

  def match_metadata(*rule)
    metadata = {}
    metadata = rule.pop if rule.last.is_a?(Hash)
    m = Matcher.new(rule)
    m.match?("metadata" => metadata)
  end

  describe "functions" do
    it "and should behave" do
      matches("and", true, true).should == true
      matches("and", true, true, false, true).should == false
    end

    it "or should behave" do
      matches("or", true, true).should == true
      matches("or", true, true, false, true).should == true
      matches("or", false, false, false).should == false
    end

    it "not should behave" do
      matches("not", 1).should == false
      matches("not", false).should == true
      matches("not", true).should == false
    end

    it "metadata should behave" do
      match_metadata("=", ["metadata", "f1"], true, { "f1" => true }).should == true
      match_metadata("=", ["metadata", "f1"], false, { "f1" => false }).should == true
      match_metadata("=", ["metadata", "f1"], 'abc', { "f1" => 'abc' }).should == true
      expect { match_metadata("=", ["metadata", "f1"], false, { "f1" => []}) }.
          to raise_error RuleEvaluationError, /cannot evaluate Array returned from metadata f1/
      expect { match_metadata("=", ["metadata", "f1"], false, { "f1" => {}}) }.
          to raise_error RuleEvaluationError, /cannot evaluate Hash returned from metadata f1/
    end

    it "fact should behave" do
      matches("fact", "f1", { "f1" => "true" }).should == true
      matches("fact", "f1", { "f1" => false  }).should == false
    end

    it "fact should raise if fact not found and one argument given" do
      expect do
        matches("fact", "f2", { "f1" => "true" })
      end.to raise_error RuleEvaluationError
    end

    it "fact should return the default if fact not found" do
      matches("fact", "f1", false, { "f1" => true }).should == true
      matches("fact", "f2", false, { "f1" => true }).should == false
    end

    ["fact", "metadata", "state"].each do |func|
      it "#{func} should work if nil is passed in for #{func}" do
        m = Matcher.new([func, "f1"])
        expect do
          # This used to fail trying to call nil.[]
          m.match?({})
        end.to  raise_error RuleEvaluationError
      end
    end

    describe "tag function" do
      it "should complain when tag does not exist" do
        expect do
          matches("tag", "t1")
        end.to raise_error RuleEvaluationError
      end

      it "should return true when tag matches" do
        tag = Fabricate(:tag, :rule => ["=", "1", "1"])
        matches("tag", tag.name).should be_true
      end

      it "should return false when tag does not match" do
        tag = Fabricate(:tag, :rule => ["=", "1", "0"])
        matches("tag", tag.name).should be_false
      end
    end

    it "eq should behave" do
      matches("=", 1, 1).should == true
      matches("=", 1, 2).should == false
      matches("=", "abc", "abc").should == true
      matches("=", "abc", "abcd").should == false
      matches("=", "[]", "[]").should == true
    end

    describe "like function" do
      [['abc', 'abc'], ['abc', 'a.c'], ['abc', 'a.+'], ['abc', 'a.*'],
       ['abc', 'ab'], ['abc', ''], ['abc', '\Aabc\z'], ['abc', '^abc$']].each do |str, reg|
        it "matches with #{str.inspect} and #{reg.inspect}" do
          matches("like", str, reg).should == true
        end
      end
      [['abc', 'def'], ['abc', 'z'], ['3', '#{1+2}'], ['abc', '\Abc\z'],
       ['abc', '\zabc\A'], ['abc', '$abc^']].each do |str, reg|
        it "fails with #{str.inspect} and #{reg.inspect}" do
          matches("like", str, reg).should == false
        end
      end
      it "fails with invalid regular expression '*'" do
        m = Matcher.new(["like", 'abc', '*'])
        m.should_not be_valid
        m.errors.should == [<<-EOF.strip]
          invalid regular expression supplied to `like` for argument 1: target of repeat operator is not specified: /*/
        EOF
      end
    end

    it "neq should behave" do
      matches("!=", 1, 1).should == false
      matches("!=", 1, 2).should == true
      matches("!=", "abc", "abc").should == false
      matches("!=", "abc", "abcd").should == true
    end

    it "in should behave" do
      matches("in", "a", "b", "c", "a").should == true
      matches("in", "x", "b", "c", "a").should == false
    end

    describe "num" do
      it "should behave for valid integers" do
        matches("=", ["num", 9      ], 9 ).should == true
        matches("=", ["num", "10"   ], 0 ).should == false
        matches("=", ["num", "0xf"  ], 15).should == true
        matches("=", ["num", "0b110"], 6 ).should == true
        matches("=", ["num", "027"  ], 23).should == true
      end

      it "should behave for valid floats" do
        matches("=", ["num", 5.4  ], 5  ).should == false
        matches("=", ["num", 5.4  ], 5.4).should == true
        matches("=", ["num", "2.7"], 2.7).should == true
        matches("=", ["num", "1e5"], 1e5).should == true
      end

      it "should raise exceptions for invalid numbers" do
        expect {matches("=", ["num", true], 1)}.to raise_error RuleEvaluationError
        expect {matches("=", ["num", "2t"], 2)}.to raise_error RuleEvaluationError
        expect {matches("=", ["num", "a2"], 2)}.to raise_error RuleEvaluationError
        expect {matches("=", ["num", nil ], 0)}.to raise_error RuleEvaluationError
      end
    end

    describe "str" do
      it "should behave for valid integers" do
        matches("=", ["str", 9      ], "9" ).should == true
        matches("=", ["str", "10"   ], "0" ).should == false
        matches("=", ["str", "0xf"  ], "0xf").should == true
        matches("=", ["str", "0b110"], "0b110" ).should == true
        matches("=", ["str", "027"  ], "027").should == true
      end

      it "should behave for valid floats" do
        matches("=", ["str", 5.4  ], "5.4").should == true
        matches("=", ["str", "2.7"], "2.7").should == true
        matches("=", ["str", "1e5"], "1e5").should == true
      end

      it "should behave for valid booleans and nil" do
        matches("=", ["str", true ], "true").should == true
        matches("=", ["str", false], "false").should == true
        matches("=", ["str", nil], '').should == true
      end
    end

    it "gte should behave" do
      matches("gte", 3.5, 4).should == false
      matches(">=",  4,   4).should == true
      matches("gte", 100, 10).should == true
    end

    it "gt should behave" do
      matches("gt", 89, 34 ).should == true
      matches(">",  1,  2.5).should == false
    end

    it "lte should behave" do
      matches("lte", 4.0,  4   ).should == true
      matches("lte", 2.3,  5   ).should == true
      matches("<=",  2.45, 2.44).should == false
    end

    it "lt should behave" do
      matches("<",  4,   3  ).should == false
      matches("lt", 3.5, 3.6).should == true
    end

    it "lower should behave" do
      matches("=", ["lower", "ABC"], "abc").should == true
      matches("=", ["lower", "ABC"], "ABC").should_not == true
      matches("=", ["lower", ["fact", "f1"]], "abc",
            { "f1" => "ABC" }).should == true
    end

    it "upper should behave" do
      matches("=", ["upper", "abc"], "ABC").should == true
      matches("=", ["upper", "abc"], "abc").should_not == true
      matches("=", ["upper", ["fact", "f1"]], "ABC",
            { "f1" => "abc" }).should == true
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

    it "should allow strings for 'like' function" do
      Matcher.new(["like", true, false]).should_not be_valid
      Matcher.new(["like", 1, 2]).should_not be_valid
      Matcher.new(["like", "abc", false]).should_not be_valid
      Matcher.new(["like", 1, "abc"]).should_not be_valid
      Matcher.new(["like", "abc", "def"]).should be_valid
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

    it "should require numbers for lte" do
      Matcher.new(["lte", 5, 3.0]).should be_valid
      Matcher.new(["<=",  1e15, 8]).should be_valid
      Matcher.new(["lte", "5", 17]).should_not be_valid
    end

    it "should require numbers for lt" do
      Matcher.new(["lt", 8, 2.4]).should be_valid
      Matcher.new(["<",  7.553, 21]).should be_valid
      Matcher.new(["lt", "9", false]).should_not be_valid
    end

    it "should require numbers for gte" do
      Matcher.new(["gte", 3, 1]).should be_valid
      Matcher.new([">=",  6.8, 8.6]).should be_valid
      Matcher.new(["gte", "1", 1]).should_not be_valid
    end

    it "should require numbers for gt" do
      Matcher.new(["gt", 1, 4]).should be_valid
      Matcher.new([">",  8, 4.7]).should be_valid
      Matcher.new(["gt", true, 3]).should_not be_valid
    end

    it "should require string for lower" do
      Matcher.new(["=", ["lower", "ABC"], "abc"]).should be_valid
      Matcher.new(["=", ["lower", 1], "abc"]).should_not be_valid
      expect { matches("=", ["lower", ["fact", "f1"]], "123", { "f1" => 123 }) }.
          to raise_error(RuleEvaluationError, /argument to 'lower' should be a string but was Fixnum/)
    end

    it "should require string for upper" do
      Matcher.new(["=", ["upper", "abc"], "abc"]).should be_valid
      Matcher.new(["=", ["upper", 1], "abc"]).should_not be_valid
      expect { matches("=", ["upper", ["fact", "f1"]], "123", { "f1" => 123 }) }.
          to raise_error(RuleEvaluationError, /argument to 'upper' should be a string but was Fixnum/)
    end

    it "should require that top-level functions return booleans" do
      Matcher.new(["=",true, false]).should be_valid
      Matcher.new(["!=",true, false]).should be_valid
      Matcher.new(["or",true, false]).should be_valid
      Matcher.new(["and",true, false]).should be_valid
      Matcher.new(["in",true, false]).should be_valid
      Matcher.new(["fact","three"]).should_not be_valid
    end

    it "should type the return of num as Numeric" do
      Matcher.new([">", ["num", "7"], 3]).should be_valid
    end

    it "should type the return of num as String" do
      Matcher.new(["=", ["str", 7], "7"]).should be_valid
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

  it "should return a reasonable message when datatype doesn't match" do
    m = Matcher.new([">=", 1, ["fact", "processorcount"]])
    m.should_not be_valid
    m.errors.should == ["could return incompatible datatype(s) from function 'fact' ([String, TrueClass, FalseClass, NilClass]) for argument 1. Function '>=' expects ([Numeric])"]
  end

  it "should return a reasonable message when root datatype doesn't match" do
    m = Matcher.new(["fact", "processorcount"])
    m.should_not be_valid
    m.errors.should == ["could return incompatible datatype(s) from function 'fact' ([String, Numeric, NilClass]). Rule expects ([TrueClass, FalseClass])"]
  end

  it "should return a reasonable message when non-array datatype doesn't match" do
    m = Matcher.new([">=", 1, "three"])
    m.should_not be_valid
    m.errors.should == ["attempts to pass \"three\" of type String to '>=' for argument 1, but only [Numeric] are accepted"]
  end

  it "should handle nested evaluation" do
    matches("and", ["=", ["fact", "f1"], 42],
                 ["!=", ["fact", "f2"], 43],
          { "f1" => 42, "f2" => 42 }).should == true
    matches("and", ["in", ["fact", "f1"], 41, 42, 43, 44],
                 ["!=", ["fact", "f2"], 42],
          { "f1" => 42, "f2" => 42 }).should == false
  end
end
