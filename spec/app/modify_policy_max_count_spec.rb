# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::ModifyPolicyMaxCount do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  let(:policy) { Fabricate(:policy) }
  let(:command_hash) { { "name" => policy.name, "max_count" => 1 } }

  def set_max_count(count=nil)
    hash = count.nil? ? {"name" => policy.name, "no_max_count" => true} :
        { "name" => policy.name, "max_count" => count }
    command 'modify-policy-max-count', hash
  end

  context "/api/commands/modify-policy-max-count" do
    before :each do
      header 'content-type', 'application/json'
      authorize 'fred', 'dead'
    end

    it_behaves_like "a command"

    it "should not accept a string for max_count" do
      set_max_count("2")
      last_response.status.should == 422
    end

    it "should reject a non-integer string for max_count" do
      set_max_count("a")
      last_response.status.should == 422
      last_response.json['error'].should == 'max_count should be a number, but was actually a string'
    end

    it "should allow increasing the max_count" do
      policy.max_count = 1
      policy.save

      set_max_count(2)
      last_response.status.should == 202

      policy.reload
      policy.max_count.should == 2
    end

    it "should allow lifting the max_count altogether" do
      set_max_count(nil)
      last_response.status.should == 202

      policy.reload
      policy.max_count.should be_nil
    end

    it "should allow setting to zero" do
      set_max_count(0)
      last_response.status.should == 202

      policy.reload
      policy.max_count.should == 0
    end

    it "should throw error when both max_count and no_max_count are absent" do
      command 'modify-policy-max-count', {'name' => policy.name}
      last_response.status.should == 422
      last_response.json['error'].should ==
          'the command requires one out of the max_count, no_max_count attributes to be supplied'
    end

    it "should fail when trying to lower the max_count below the number of currently bound nodes" do
      policy.max_count = 2
      policy.save
      2.times do
        node = Fabricate(:node)
        node.bind(policy)
        node.save
      end

      set_max_count(1)
      last_response.status.should == 400
      last_response.json['error'].should ==
          'There are currently 2 nodes bound to this policy. Cannot lower max_count to 1'

      policy.reload
      policy.max_count.should == 2
    end

  end
end
