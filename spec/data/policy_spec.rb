require_relative "../spec_helper"

describe Razor::Data::Policy do

  before(:each) do
    use_recipe_fixtures
    @node = Fabricate(:node, :hw_hash => { "mac" => ["abc"] },
                      :facts => { "f1" => "a" })
    @tag = Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
    @repo = Fabricate(:repo)
  end

  it "binds to a matching node" do
    pl = Fabricate(:policy, :repo => @repo, :recipe_name => "some_os")
    pl.add_tag(@tag)
    pl.save
    @node.add_tag(@tag)

    Policy.bind(@node)
    @node.policy.should == pl
    @node.log.last["event"].should == "bind"
    @node.log.last["policy"].should == pl.name
  end

  it "does not save a policy if the named recipe does not exist" do
    pl = Fabricate(:policy, :repo => @repo, :recipe_name => "some_os")
    expect do
      pl.recipe_name = "no such recipe"
      pl.save
    end.to raise_error(Sequel::ValidationFailed)
  end

  describe "max_count" do
    it "binds if there is room" do
      pl = Fabricate(:policy, :repo => @repo, :recipe_name => "some_os",
                       :max_count => 1)
      pl.add_tag(@tag)
      pl.save
      @node.add_tag(@tag)

      Policy.bind(@node)
      @node.policy.should == pl
    end

    it "does not bind if there is no room" do
      pl = Fabricate(:policy, :repo => @repo, :recipe_name => "some_os",
                       :max_count => 0)
      pl.add_tag(@tag)
      pl.save
      Policy.bind(@node)
      @node.policy.should be_nil
    end

    # It would be nice to test that we do not exceed max_count bindings in
    # racy situations, but I don't see a good way to do that without
    # modifying Policy.bind in a way that let's us inject the race reliably
  end

  it "does not bind disabled policy" do
    pl = Fabricate(:policy, :repo => @repo, :recipe_name => "some_os",
                     :enabled => false)
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should be_nil
  end

  context "ordering" do
    before(:each) do
      @p1 = Fabricate(:policy, :rule_number => 1)
      @p2 = Fabricate(:policy, :rule_number => 2)
    end

    def check_move(where, other, list)
      p  = Fabricate(:policy)
      if where
        p.move(where, other)
        p.save
      end

      list = list.map { |x| x == :_ ? p.id : x.id }
      Policy.all.map { |p| p.id }.should == list
    end

    it "moves existing policy to the end" do
      @p1.move(:after, @p2)
      Policy.all.map { |p| p.id }.should == [ @p2.id, @p1.id ]
    end

    it "creates policies at the end of the list" do
      check_move(nil, nil, [@p1, @p2, :_])
    end

    describe 'before' do
      it "p1 creates at the head of the table" do
        check_move(:before, @p1, [:_, @p1, @p2])
      end

      it "p2 goes between p1 and p2" do
        check_move(:before, @p2, [@p1, :_, @p2])
      end
    end

    describe "after" do
      it "p1 goes between p1 and p2" do
        check_move(:after, @p1, [@p1, :_, @p2])
      end

      it "p2 goes to the end of the table" do
        check_move(:after, @p2, [@p1, @p2, :_])
      end
    end
  end
end
