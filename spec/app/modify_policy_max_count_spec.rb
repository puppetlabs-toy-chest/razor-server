# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "modify-policy-max-count" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  let(:policy) { Fabricate(:policy) }

  def set_max_count(count=nil)
    post '/api/commands/modify-policy-max-count',
         { "name" => policy.name, "max-count" => count }.to_json
  end

  context "/api/commands/modify-policy-max-count" do
    before :each do
      header 'content-type', 'application/json'
      authorize 'fred', 'dead'
    end

    it "should require that max-count is present" do
      post '/api/commands/modify-policy-max-count',
        { "name" => policy.name }.to_json
      last_response.status.should == 422
      last_response.body.should =~ /max-count/
    end

    it "should accept a string for max-count" do
      set_max_count("2")
      last_response.status.should == 202
    end

    it "should reject a non-integer string for max-count" do
      set_max_count("a")
      last_response.status.should == 422
      last_response.json['error'].should =~ /'a' is not a valid integer/
    end

    it "should allow increasing the max-count" do
      policy.max_count = 1
      policy.save

      set_max_count(2)
      last_response.status.should == 202

      policy.reload
      policy.max_count.should == 2
    end

    it "should allow lifting the max-count alltogether" do
      set_max_count(nil)
      last_response.status.should == 202

      policy.reload
      policy.max_count.should be_nil
    end

    it "should fail when trying to lower the max-count below the number of currently bound nodes" do
      policy.max_count = 2
      policy.save
      2.times do
        node = Fabricate(:node)
        node.bind(policy)
        node.save
      end

      set_max_count(1)
      last_response.status.should == 400

      policy.reload
      policy.max_count.should == 2
    end

  end
end
