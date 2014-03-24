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

  describe 'start' do
    it "should set command and params" do
      cmd = Command.start('hello', { "param" => "value" }, 'fred')
      cmd.command.should == 'hello'
      cmd.params.should == { "param" => "value" }
      cmd.status.should be_nil
      cmd.submitted_at.should_not be_nil
      cmd.submitted_by.should == 'fred'
    end

    it "should accept a user of nil" do
      cmd = Command.start('hello', {}, nil)
      cmd.submitted_by.should be_nil
    end
  end

  describe 'store' do
    it "without arguments should mark a command as finished and save it" do
      cmd = Command.start('hello', {}, nil)
      cmd.store
      cmd = Command[cmd.id]
      cmd.status.should == 'finished'
      cmd.finished_at.should_not be_nil
    end

    it "should overwrite status when supplied" do
      cmd = Command.start('hello', {}, nil)
      cmd.status = 'nonsense'
      cmd.store('pending')
      cmd = Command[cmd.id]
      cmd.status.should == 'pending'
      cmd.finished_at.should be_nil
    end

    it "should set finished_at when transitioning to 'finished'" do
      cmd = Command.start('hello', {}, nil)
      cmd.store('pending')
      cmd.finished_at.should be_nil
      cmd.store('finished')
      cmd = Command[cmd.id]
      cmd.finished_at.should_not be_nil
    end

    it "should preserve status if non passed in" do
      cmd = Command.start('hello', {}, nil)
      cmd.status = 'pending'
      cmd.store
      cmd = Command[cmd.id]
      cmd.status.should == 'pending'
    end
  end
end
