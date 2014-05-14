# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "move policy command" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
    header 'content-type', 'application/json'
    @p1 = Fabricate(:policy, :name => 'first', :rule_number => 1)
    @p2 = Fabricate(:policy, :name => 'second', :rule_number => 2)
    @p3 = Fabricate(:policy, :name => 'third', :rule_number => 3)
  end
  let(:command_hash) do
    {
        "name" => @p1.name,
        "after" => @p2.name
    }
  end

  def move_policy(what, where, other)
    input = {}
    input["name"] = what.name if what
    input[where.to_s] = { "name" => other.name } if where

    command 'move-policy', input
  end

  def check_order(*list)
    last_response.json['error'].should be_nil
    last_response.status.should == 202
    Policy.all.map { |p| p.id }.should == list.map { |x| x.id }
  end

  describe Razor::Command::MovePolicy do
    it_behaves_like "a command"
  end

  describe "spec" do
    it "requires a name for the policy to move" do
      move_policy(nil, :after, @p1)
      last_response.json['error'].should =~ /name is a required attribute, but it is not present/
      last_response.status.should == 422
    end

    it "rejects moving a nonexisting policy" do
      @p1.name = @p1.name + " (not really)"
      move_policy(@p1, :after, @p2)
      last_response.json['error'].should =~ /name must be the name of an existing policy, but is 'first \(not really\)'/
      last_response.status.should == 404
    end

    it "requires either before or after to be present" do
      move_policy(@p1, nil, nil)
      last_response.json['error'].should =~ /requires one out of the after, before attributes to be supplied/
      last_response.status.should == 422
    end

    it "requires name in before to be present" do
      command 'move-policy', {
          :name => @p1.name,
          :before => { },
      }
      last_response.json['error'].should == 'before should be a string, but was actually a object'
      last_response.status.should == 422
    end

    it "requires name in after to be present" do
      command 'move-policy', {
          :name => @p1.name,
          :after => { },
      }
      last_response.json['error'].should == 'after should be a string, but was actually a object'
      last_response.status.should == 422
    end

    it "does not allow both before and after" do
      command 'move-policy', {
        :name => @p1.name,
        :before => { :name => @p2.name },
        :after => { :name => @p3.name }
      }
      last_response.status.should == 422
      last_response.json['error'].should =~ /if before is present, after must not be present/
    end
  end

  it "should move second before first" do
    move_policy(@p2, :before, @p1)
    check_order @p2, @p1, @p3
  end

  it "should move third before second" do
    move_policy(@p3, :before, @p2)
    check_order @p1, @p3, @p2
  end

  it "should move first after third" do
    move_policy(@p1, :after, @p3)
    check_order @p2, @p3, @p1
  end

  it "should move second after third" do
    move_policy(@p2, :after, @p3)
    check_order @p1, @p3, @p2
  end

  it "should conform to allow the long form in 'before' spec" do
    input = {'name' => @p3.name, 'before' => @p1.name }
    command 'move-policy', input
    check_order @p3, @p1, @p2
  end

  it "should conform to allow the long form in 'after' spec" do
    input = {'name' => @p1.name, 'after' => @p3.name }
    command 'move-policy', input
    check_order @p2, @p3, @p1
  end
end
