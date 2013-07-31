require_relative '../spec_helper'
require 'json'

describe Razor::API::Tag do

  let :tag_obj do
    Razor::Data::Tag.create(:name=>"tag 0",:rule=>["=", ["fact", "zero"], "0"])
  end

  subject(:tag) { Razor::API::Tag.new(tag_obj) }

  it "can output json" do
    should respond_to(:to_json)
  end

  describe "#to_hash" do
    subject(:hash) {tag.to_hash}

      it "makes JSON that mirrors the hash value" do 
        Hash[ hash.map {|k,v| [k.to_s, v] } ].should == JSON.parse(tag.to_json)
      end 

      it "has only the specified keys" do 
        expected_keys = [:name, :rule] 

        should have(expected_keys.size).keys 
        expected_keys.each do |key| 
          hash.should have_key(key) 
        end 
      end 

      describe :name do  
        subject { tag.to_hash[:name] } 

        it { should be_a String } 
      end 

      describe :rule do 
        subject { tag.to_hash[:rule] } 

        it { should be_an Array } 
      end 
  end
end
