require_relative "../spec_helper"

describe Razor::Data::Policy do

  before(:each) do
    @node = Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
    @tag = Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
    @image = make_image
  end

  it "binds to a matching node" do
    pl = Policy.create(:name => "p1", :enabled => true, :image => @image,
                       :hostname_pattern => "host%n")
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should == pl
  end

  it "does not bind disabled policy" do
    pl = Policy.create(:name => "p1", :enabled => false, :image => @image,
                       :hostname_pattern => "host%n")
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should be_nil
  end
end
