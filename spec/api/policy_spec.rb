require_relative '../spec_helper'
require 'json'

describe Razor::API::Policy do

  before(:each) do
    @node = Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
    @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
    @image = make_image
    @p = make_policy(:image => @image, :installer_name => "dummy")
    @p2 = make_policy(:image => @image, :installer_name => "dummy",
                      :max_count=>5, :name=>"dummy policy")
    @policy = Razor::API::Policy.new(@p)
  end

  subject { @policy }

  it "can output hashes" do
    should respond_to(:to_hash)
    @policy.to_hash.should be_a(Hash)
  end

  it "can output json" do
    should respond_to(:to_json)
    @policy.to_json.should be_a(String)
  end

  it "makes JSON that mirrors the hash value" do
    @policy.to_hash.should == JSON.parse(@policy.to_json,:symbolize_names=>true)
  end

  it "has only the specified keys" do
    expected_keys = [
      :id, :name, :image_id, :enabled, :max_count,
      :configuration, :tags
    ]

    @policy.to_hash.should have(expected_keys.size).keys
    expected_keys.each do |key|
      @policy.to_hash.should have_key(key)
    end
  end

  describe :id do 
    subject { @policy.to_hash[:id] }
    
    it { should be_a Fixnum }
    it { should == @p.id }
  end

  describe :name do
    subject { @policy.to_hash[:name] }

    it { should be_a String }
    it { should == @p.name }
  end

  describe :image_id do
    subject { @policy.to_hash[:image_id] }
    it { should be_a Fixnum }
    it { should == @image.id }
  end

  describe :enabled do
    subject { @policy.to_hash[:enabled] }

    it "should be a boolean" do
     [TrueClass, FalseClass].should include @policy.to_hash[:enabled].class
    end
    it { should == @p.enabled }
 end

  describe :max_count do
    subject { @policy.to_hash[:max_count] }

    it "Should be a Fixnum or nil" do
      [Fixnum, NilClass].should include(@policy.to_hash[:max_count].class)
    end
    context "With a max_count of 0" do
      subject { @policy.to_hash[:max_count] }
      
      it { should be_nil } # since @p.max_count is 0
    end
    context "With a max count not 0" do
      subject { Razor::API::Policy.new(@p2).to_hash[:max_count] }

      it { should_not be_nil } # since @p2.max_count != 0 
      it { should == @p2.max_count }
    end
  end

  describe :configuration do
    subject { @policy.to_hash[:configuration] }

    it { should be_a Hash }
    it { should have_key :hostname_pattern }
    it { should have_key :domain_name }
    it { should have_key :root_password }
  end

  describe :tags do
    subject { @policy.to_hash[:tags] }
    it { should be_an Array }
    it "has only string values" do
      should be_all { |t| t.is_a? String }
    end
  end
end
