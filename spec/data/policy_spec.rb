require_relative "../spec_helper"

describe Razor::Data::Policy do

  before(:each) do
    @node = Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
    @tag = Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
    @image = make_image
  end

  it "binds to a matching node" do
    pl = make_policy(:image => @image, :installer_name => "dummy")
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should == pl
  end

  describe "max_count" do
    it "binds if there is room" do
      pl = make_policy(:image => @image, :installer_name => "dummy",
                       :max_count => 1)
      pl.add_tag(@tag)
      pl.save
      Policy.bind(@node)
      @node.policy.should == pl
    end

    it "does not bind if there is no room" do
      pl = make_policy(:image => @image, :installer_name => "dummy",
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
    pl = make_policy(:image => @image, :installer_name => "dummy",
                     :enabled => false)
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should be_nil
  end
end
