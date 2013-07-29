require_relative '../spec_helper'
require 'json'

describe Razor::API::Policy do

  let :node do
    Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
  end

  let :tag do
    Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
  end

  let(:image) { make_image }

  let :policy_obj1 do
   make_policy(:image => image, :installer_name => "dummy",:enabled=>false,:max_count=>0)
  end

  let :policy_obj2 do
    make_policy(:image => image, :installer_name => "dummy",
                      :max_count=>5, :name=>"dummy policy",:enabled=>true)
  end

  subject(:policy) { Razor::API::Policy.new(policy_obj1) }


  it "can output hashes" do
    should respond_to(:to_hash)
  end

  it "can output json" do
    should respond_to(:to_json)
  end

  describe "#to_hash" do
    subject(:hash) { policy.to_hash }

    it "makes JSON that mirrors the hash value" do
      should == JSON.parse(policy.to_json,:symbolize_names=>true)
    end

    it "has only the specified keys" do
      expected_keys = [
        :id, :name, :image_id, :enabled, :max_count,
        :configuration, :tags
      ]


      should have(expected_keys.size).keys
      expected_keys.each do |key|
        should have_key(key)
      end
    end

    describe :id do 
      subject { hash[:id] }

      it { should be_a Fixnum }
      it { should == policy_obj1.id }
    end

    describe :name do
      subject { hash[:name] }

      it { should be_a String }
      it { should == policy_obj1.name }
    end

    describe :image_id do
      subject { hash[:image_id] }
      it { should be_a Fixnum }
      it { should == image.id }
    end

    describe :enabled do
      subject { hash[:enabled] }
      it { should be_false }
   end

    describe :max_count do
      
      context "With a max_count of 0" do
        subject(:max_count) { policy.to_hash[:max_count] }
        it { should be_nil }
      end

      context "With a max count not 0" do
        subject { Razor::API::Policy.new(policy_obj2).to_hash[:max_count] }
        
        it { should_not be_nil }
      end
    end

    describe :configuration do
      subject { policy.to_hash[:configuration] }


      it { should be_a Hash }
      it { should have_key :hostname_pattern }
      it { should have_key :domain_name }
      it { should have_key :root_password }
    end

    describe :tags do
      subject { policy.to_hash[:tags] }
      it { should be_an Array }
      it "has only string values" do

        should be_all { |t| t.is_a? String }

      end
    end
  end
end