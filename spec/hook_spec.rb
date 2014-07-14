# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::Hook do
  Hook = Razor::Hook
  good_command_no_metadata = %q[ echo testing >> /dev/null ]
  good_command_with_metadata = %q| echo '{ "update": { "key1": "val1" }, "remove": [ "m1" ] }' |
  bad_command = %q[ which no_such_command >> /dev/null 2>&1 ]

  before(:each) do
    use_hook_fixtures
  end

  describe "find_all_for_event" do
    it "should create an array of hook objects for each script it finds" do
      hooks = Razor::Hook.find_all_for_event('node_create')
      hooks.length.should == 2
      hooks.first.event.should == 'node_create'
      hooks.first.file.should =~ /\/create/
    end
  end

  describe "run_command" do
    it "should set the output and status from the scipt run" do
      testhook = Hook.new('myscript', 'myevent')

      testhook.run_command(good_command_no_metadata)
      testhook.output.should == ""
      testhook.status.should == 0
      
      testhook.run_command(good_command_with_metadata)
      testhook.output.should == %q|{ "update": { "key1": "val1" }, "remove": [ "m1" ] }|
      testhook.status.should == 0
      
      testhook.run_command(bad_command)
      testhook.output.should == ""
      testhook.status.should == 1
    end
  end
  
  describe "apply_metadata" do 
    it "should raise an error if the data is not valid JSON" do
      node = Fabricate(:node)
      testhook = Hook.new('myscript', 'myevent')
      testhook.save_output( %q| not real JSON | )
      expect { testhook.apply_metadata(node) }.to raise_error(Razor::HookInvalidJSON)
    end
    
    it "should raise an error if the data is not a hash" do
      node = Fabricate(:node)
      testhook = Hook.new('myscript', 'myevent')
      testhook.save_output( %q| ["not", "a", "hash"] | )
      expect { testhook.apply_metadata(node) }.to raise_error(Razor::HookReturnError)
    end
    
    it "should raise an error if the node objects rejects the metadata" do
      node = Fabricate(:node)
      testhook = Hook.new('myscript', 'myevent')
      testhook.save_output( %q| { "update": [ "key1", "val1" ], "remove": "m1" } | )
      expect { testhook.apply_metadata(node) }.to raise_error(Razor::HookReturnError)
    end

    it "should apply valid metadata to the node" do
      node = Fabricate(:node)
      testhook = Hook.new('myscript', 'myevent')
      testhook.save_output( %q| { "update": { "key1": "val1" }, "remove": [ "m1" ] } | )
      testhook.apply_metadata(node)
      node.metadata.should == { 'key1' => 'val1' }
    end
  end
  
  describe "run_event_hooks" do
    it "should run each hook for the event against the node" do
      node = Fabricate(:node)

      Razor::Hook.run_event_hooks(node, 'node_create')
      node.metadata['create'].should == 'true'
      node.metadata['id'].should == node.id
    end
  end
end
