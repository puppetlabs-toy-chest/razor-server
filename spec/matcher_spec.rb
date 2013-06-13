describe Razor::Matcher do
  Matcher = Razor::Matcher

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
      match("fact", "f2", { "f1" => "true" }).should == false
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

  it "should handle nested evaluation" do
    match("and", ["=", ["fact", "f1"], 42],
                 ["!=", ["fact", "f2"], 43],
          { "f1" => 42, "f2" => 42 }).should == true
    match("and", ["in", ["fact", "f1"], 41, 42, 43, 44],
                 ["!=", ["fact", "f2"], 42],
          { "f1" => 42, "f2" => 42 }).should == false
  end
end
