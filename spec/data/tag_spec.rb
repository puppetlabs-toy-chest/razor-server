require_relative '../spec_helper'

describe Razor::Data::Tag do
  include TorqueBox::Injectors

  class MockNode
    attr_reader :facts

    def initialize(facts)
      @facts = facts
    end
  end

  let (:tag0_hash) {
    { "name" => "tag0",
      "rule" => ["in", ["fact", "f1"], "a", "b", "c"] }
  }

  let (:tag0) { Tag.create(tag0_hash) }

  let(:node) { Fabricate(:node, :facts => { "a" => 42 }) }

  describe "::match" do
    it "matches on the right facts" do
      tag0
      Tag.match(MockNode.new("f1" => "c")).should == [ tag0 ]
      Tag.match(MockNode.new("f1" => "x")).should == []
    end

    it "raises for bad rule matchers" do
      bad_tag = Tag.create(:name=> "bad", :rule => ["=", 1, ["fact", "not"]])
      expect { Tag.match(MockNode.new()) }.to raise_error ArgumentError
    end
  end

  context "when rule is nil" do
    subject(:tag) {Tag.create(:name => "t1", :rule => ["=", 1, 1])}
    it { should be_valid }
  end

  context "when rule is valid" do
    subject(:tag) {Tag.create(:name=>"t2", :rule => ["=",["fact","five"], 5])}
    it { should be_valid }
  end

  context "when rule is not valid" do
    subject(:tag) {Tag.new(:name=>"t2", :rule => ["yes","no"])}
    it { should_not be_valid }
    it { tag.valid?; tag.errors[:matcher].should_not be_empty }
  end

  describe "find_or_create_with_rule" do
    def that_method(data)
      Razor::Data::Tag::find_or_create_with_rule(data)
    end

    it "must raise an error if no name is given" do
      expect { that_method({}) }.to raise_error ArgumentError
    end

    it "must find an existing tag" do
      tag0
      that_method("name" => tag0.name).should == tag0
    end

    it "must find an existing tag if the rules are identical" do
      tag0
      that_method(tag0_hash).should == tag0
    end

    it "must raise an error if tag exists but rules do not match" do
      tag0
      hash = tag0_hash.update("rule" => ["=", 1, 1])
      expect { that_method(tag0_hash) }.to raise_error ArgumentError
    end

    it "must create a new tag when rule is given" do
      tag = that_method(tag0_hash)
      tag.should_not be_nil
      tag.name.should == tag0_hash["name"]
    end

    it "must raise an error when a new tag has no rule" do
      expect { that_method("name" => "new_tag") }.to raise_error ArgumentError
    end

    it "must tag an existing matching node" do
      node # Cause node to be created
      tag = that_method("name" => "aTag",
                        "rule" => ["=", ["fact", "a"], 42])
      check_and_process_eval_nodes(tag)

      node.tags.should include(tag)
    end

    it "must not tag an existing node that does not match" do
      node # Cause node to be created

      tag = that_method("name" => "aTag",
                        "rule" => ["!=", ["fact", "a"], 42])
      check_and_process_eval_nodes(tag)

      node.tags.should_not include(tag)
    end
  end

  describe "updating the tag's rule" do

    let(:tag) { Fabricate(:tag, :name => "aTag", :rule => ["=", 1, 1]) }

    it "should tag a matching existing node" do
      node # Cause node to be created

      tag.rule = ["=", ["fact", "a"], 42]
      tag.save

      check_and_process_eval_nodes(tag)

      node.tags.should include(tag)
    end

    it "should not tag an existing node that does not match" do
      node # Cause node to be created

      tag.rule = ["!=", ["fact", "a"], 42]
      tag.save

      check_and_process_eval_nodes(tag)

      node.tags.should_not include(tag)
    end
  end

  it "should not publish 'eval_nodes' if the rule hasn't changed" do
    queue = fetch('/queues/razor/sequel-instance-messages')
    tag = Fabricate(:tag, :name => "aTag", :rule => ["=", 1, 1])

    queue.remove_messages

    tag.name = "aTag_changed"
    tag.save

    queue.count_messages.should == 0
  end

  def check_and_process_eval_nodes(tag)
    queue = fetch('/queues/razor/sequel-instance-messages')

    expect{}.to have_published(
     'class'  => tag.class.name,
     'instance' => include(:id => tag.id),
     'message' => 'eval_nodes').on(queue)

    tag.public_send('eval_nodes')
  end
end
