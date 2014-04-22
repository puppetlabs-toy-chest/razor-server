# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "cancel command" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/cancel-command" do
    before :each do
      header 'content-type', 'application/json'
    end
    let(:cmd) do
      Fabricate(:command)
    end

    let(:command_hash) do
      { :name => cmd.id }
    end

    def cancel_command(input = nil)
      input ||= command_hash
      command 'cancel-command', input
    end

    it "should reject bad JSON" do
      cancel_command '{"json": "not really..."'
      last_response.status.should == 400
      last_response.json["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        cancel_command input
        last_response.status.should == 400
      end
    end

    it "should fail if given invalid id" do
      cancel_command name: cmd.id + 12
      last_response.json['error'].should =~ /name must be the id of an existing command, but is '#{cmd.id + 12}'/
      last_response.status.should == 404
    end

    # Successful cancellation
    it "should return 202" do
      cancel_command

      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[id name spec]
    end

    it "should cancel the command in the database" do
      cancel_command

      cmd = Razor::Data::Command[:id => command_hash[:name]]
      cmd.should_not be_nil
      cmd.cancelled?.should be_true
      cmd.finished_at.should_not be_nil
    end
  end
end
