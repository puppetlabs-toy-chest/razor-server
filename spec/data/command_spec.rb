# -*- encoding: utf-8 -*-
require_relative "../spec_helper"

describe Razor::Data::Command do
  it "should serialize params" do
    params = { 'name' => 'n1', 'other' => 'o1' }
    cmd = Fabricate(:command)
    cmd.params = params
    cmd.save
    cmd = Command[cmd.id]
    cmd.params.should == params
  end

  it "should serialize errors" do
    err = [{ 'msg' => "Something is wrong", 'details' => "Read all about it" }]
    cmd = Fabricate(:command)
    cmd.error = err
    cmd.save
    cmd = Command[cmd.id]
    cmd.error.should == err
  end

  describe 'add_exception' do
    let (:command) { Fabricate(:command) }
    let (:exc1)    { Exception.new("exception 1") }
    let (:exc2)    { Exception.new("exception 2") }

    it "should add an exception to error" do
      command.add_exception(exc1)
      command.error.should be_an_instance_of Array
      e = command.error[0]
      e.should_not be_nil
      e.keys.should =~ %w[exception message backtrace attempted_at]
      e['exception'].should == exc1.class.name
      e['message'].should == exc1.to_s
      e['backtrace'].should == exc1.backtrace
      e['attempted_at'].should_not be_nil
    end

    it "should append to error when attempt is not given" do
      command.add_exception exc1
      command.add_exception exc2
      command.error.map { |e| e['message'] }.should == [exc1.to_s, exc2.to_s]
    end

    it "should set the error entry with the given attempt" do
      command.add_exception exc1, 1
      command.error.size.should == 2
      command.error[0].should be_nil
      command.error[1]['message'].should == exc1.to_s
    end

    it "should not overwrite an already set exception slot" do
      command.add_exception exc1, 1
      command.add_exception exc2, 1

      command.error[1]['message'].should == exc1.to_s
    end
  end
end
