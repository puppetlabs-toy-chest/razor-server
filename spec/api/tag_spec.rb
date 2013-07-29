require_relative '../spec_helper'
require 'json'

describe Razor::API::Tag do

  let :tag_obj do
    Razor::Data::Tag.create(:name=>"tag 0",:rule=>["=", ["fact", "zero"], "0"])
  end

  subject(:tag) { Razor::API::Tag.new(tag_obj) }

  it "can output hashes" do
    should respond_to(:to_hash)
    tag.to_hash.should be_a(Hash)
  end

  it "can output json" do
    should respond_to(:to_json)
    tag.to_json.should be_a(String)
  end

  it "makes JSON that mirrors the hash value" do
    Hash[ tag.to_hash.map do |k, v|
      [k.to_s, v]
    end ].should == JSON.parse(tag.to_json)
  end

  it "has only the specified keys" do
    expected_keys = [:name, :rule]

    tag.to_hash.should have(expected_keys.size).keys
    expected_keys.each do |key|
      tag.to_hash.should have_key(key)
    end
  end

  describe ":name" do 
    subject { tag.to_hash[:name] }
    
    it { should be_a String }
  end

  describe ":rule" do
    subject { tag.to_hash[:rule] }

    it { should be_an Array }
  end

end
