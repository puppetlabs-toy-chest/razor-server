require_relative "../spec_helper"

describe Razor::Data::Policy do

  before(:each) do
    use_installer_fixtures
    @node = Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
    @tag = Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
    @image = Fabricate(:image)
  end

  it "binds to a matching node" do
    pl = Fabricate(:policy, :image => @image, :installer_name => "some_os")
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should == pl
  end

  it "does not save a policy if the named installer does not exist" do
    pl = Fabricate(:policy, :image => @image, :installer_name => "some_os")
    expect do
      pl.installer_name = "no such installer"
      pl.save
    end.to raise_error(Sequel::ValidationFailed)
  end

  describe "max_count" do
    it "binds if there is room" do
      pl = Fabricate(:policy, :image => @image, :installer_name => "some_os",
                       :max_count => 1)
      pl.add_tag(@tag)
      pl.save
      Policy.bind(@node)
      @node.policy.should == pl
    end

    it "does not bind if there is no room" do
      pl = Fabricate(:policy, :image => @image, :installer_name => "some_os",
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
    pl = Fabricate(:policy, :image => @image, :installer_name => "some_os",
                     :enabled => false)
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should be_nil
  end
end
