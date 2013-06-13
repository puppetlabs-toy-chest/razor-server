describe Razor::Data::Tag do
  Tag = Razor::Data::Tag

  class MockNode
    attr_reader :facts

    def initialize(facts)
      @facts = facts
    end
  end

  it "matches on the right facts" do
    t = Tag.create(:name => "t0",
                   :rule => ["in", ["fact", "f1"], "a", "b", "c"])
    Tag.match(MockNode.new("f1" => "c")).should == [ t ]
    Tag.match(MockNode.new("f1" => "x")).should == []
  end
end
