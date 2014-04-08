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

  def move_policy(what, where, other)
    input = {}
    input["name"] = what.name if what
    input[where.to_s] = { "name" => other.name } if where

    command 'move-policy', input
  end

  def check_order(*list)
    last_response.status.should == 202
    Policy.all.map { |p| p.id }.should == list.map { |x| x.id }
  end

  describe "spec" do
    it "requires a name for the policy to move" do
      move_policy(nil, :after, @p1)
      last_response.status.should == 422
      last_response.json["error"].should =~ /required attribute name is missing/
    end

    it "rejects moving a nonexisting policy" do
      @p1.name = @p1.name + "(not really)"
      move_policy(@p1, :after, @p2)
      last_response.status.should == 404
      last_response.json["error"].should =~ /attribute name must refer to an existing instance/
    end

    it "requires either before or after to be present" do
      move_policy(@p1, nil, nil)
      last_response.status.should == 422
      last_response.json["error"] =~ /either 'before' or 'after'/
    end

    it "does not allow both before and after" do
      command 'move-policy', {
        :name => @p1.name,
        :before => { :name => @p2.name },
        :after => { :name => @p3.name }
      }
      last_response.status.should == 422
      last_response.json["error"] =~ /one of 'before' or 'after'/
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
end
