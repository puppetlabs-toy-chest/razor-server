# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::Data::Hook do
  include TorqueBox::Injectors
  let :queue do fetch('/queues/razor/sequel-instance-messages') end

  def run_message(message)
    clazz = message['class'].split('::').inject(Object) do |mod, class_name|
      mod.const_get(class_name)
    end
    obj_ref = message['instance']
    obj = clazz[obj_ref]
    method = message['message']
    arguments = message['arguments'].first
    obj.send(method, arguments)
  end

  around :each do |test|
    Dir.mktmpdir do |dir|
      Razor.config['hook_path'] = dir

      # Create the stub hook, ready to go for testing.
      hook = Pathname(dir) + 'test.hook'
      hook.mkpath
      set_hook_file('test', 'configuration.yaml' => "# no actual content\n")

      test.run
    end
  end

  def hook_type(name = 'test')
    Razor::HookType.find(name: name)
  end

  def set_hook_file(hook_name, file)
    root = Pathname(Razor.config.hook_paths.first)
    file.each do |name, content|
      file = (root + (hook_name + '.hook') + name)
      if content then
        file.open('w'){|f| f.print content }
        file.chmod(0755)
        yield file if block_given?
      else
        file.unlink
      end
    end
  end

  let (:node)   { Fabricate(:node) }

  describe "name" do
    it "name is case-insensitively unique" do
      Razor::Data::Hook.new(:name => 'hello', :hook_type => hook_type).save
      expect {
        Razor::Data::Hook.new(:name => 'HeLlO', :hook_type => hook_type).save
      }.to raise_error Sequel::UniqueConstraintViolation
    end

    it "does not accept newlines" do
      Razor::Data::Hook.new(:name => "hello\nworld", :hook_type => hook_type).
          should_not be_valid
    end
  end

  describe "hook" do
    it "should accept a Razor::HookType instance" do
      Razor::Data::Hook.new(:name => 'hello', :hook_type => hook_type).save
    end

    it "should have a Razor::HookType instance after loaded" do
      Razor::Data::Hook.new(:name => 'hello', :hook_type => hook_type).save
      loaded = Razor::Data::Hook[:name => 'hello'].hook_type
      loaded.should be_an_instance_of Razor::HookType
      loaded.name.should == hook_type.name
    end

    it "should not accept a string" do
      expect {
        Razor::Data::Hook.new(:name => 'hello', :hook_type => 'test').save
      }.to raise_error Sequel::ValidationFailed, "hook_type 'test' is not valid"
    end
  end

  describe "configuration" do
    it "should default to an empty hash" do
      instance = Razor::Data::Hook.new(:name => 'hello', :hook_type => 'test')
      instance.configuration.should == {}
    end

    it "should accept and save an empty hash" do
      Razor::Data::Hook.new(
          :name          => 'hello',
          :hook_type   => hook_type,
          :configuration => {}
      ).save
    end

    context "with configuration items defined" do
      before :each do
        configuration = {
            'server'  => {'required' => false, 'description' => 'foo'},
            'version' => {'required' => true,  'description' => 'bar'}
        }
        set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)
      end

      def new_hook(config = {})
        Razor::Data::Hook.
            new(:name => 'hello', :hook_type => hook_type, :configuration => config).
            save
      end

      it "should fail if an unknown key is passed" do
        expect {
          new_hook('server' => 'foo', 'version' => 'bar', 'other' => 'baz')
        }.to raise_error Sequel::ValidationFailed, /configuration key 'other' is not defined for this hook/
      end

      it "should fail if only unknown keys are passed" do
        configuration = {
            'server'  => {'required' => false, 'description' => 'foo'},
            'version' => {'required' => false, 'description' => 'bar'}
        }
        set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)

        expect {
          new_hook('other' => 'baz')
        }.to raise_error Sequel::ValidationFailed, /configuration key 'other' is not defined for this hook/
      end

      it "should fail if a required key is missing" do
        expect {
          new_hook 'server' => 'foo.example.com'
        }.to raise_error Sequel::ValidationFailed, /configuration key 'version' is required by this hook type, but was not supplied/
      end

      it "should respect defaults for configuration" do
        configuration = {
            'server'  => {'required' => true, 'description' => 'foo', 'default' => 'abc'},
            'other'   => {'description' => 'required-absent', 'default' => 'def'},
            'version' => {'required' => false, 'description' => 'bar'}
        }
        set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)

        hook = new_hook
        hook.configuration['server'].should == 'abc'
        hook.configuration['other'].should == 'def'
      end
    end

    it "should round-trip a rich configuration" do
      schema = {'one' => {}, 'two' => {}, 'three' => {}}
      set_hook_file('test', 'configuration.yaml' => schema.to_yaml)

      config = {"one" => 1, "two" => 2.0, "three" => ['a', {'b'=>'b'}, ['c']]}
      Razor::Data::Hook.new(
          :name          => 'hello',
          :hook_type   => hook_type,
          :configuration => config
      ).save

      Razor::Data::Hook[:name => 'hello'].configuration.should == config
    end
  end

  describe "handle" do
    it "should correctly handle an event with no applicable hooks" do
      Razor::Data::Hook.run('abc', node: Fabricate(:node))
    end
    it "should correctly handle an event with two applicable hooks" do
      first = Razor::Data::Hook.new(:name => 'first', :hook_type => hook_type).save

      second_hook = Pathname(Razor.config['hook_path']) + 'second.hook'
      second_hook.mkpath
      set_hook_file('second', 'configuration.yaml' => "# no actual content\n")
      second = Razor::Data::Hook.new(:name => 'second', :hook_type => hook_type('second')).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "standard output"
}
EOF
exit 0
      CONTENTS
      set_hook_file('second', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "standard output"
}
EOF
exit 0
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 2
      2.times { run_message(queue.receive) }
      events = Razor::Data::Event.all
      events.size.should == 2
      first_event = events.select {|e| e.hook_id == first.id }.first
      second_event = events.select {|e| e.hook_id == second.id }.first
      first_event.node_id.should == node.id
      first_event.entry['msg'].should == 'standard output'
      first_event.entry['severity'].should == 'info'
      second_event.node_id.should == node.id
      second_event.entry['msg'].should == 'standard output'
      second_event.entry['severity'].should == 'info'
    end
  end

  describe "event creation" do
    it "should create a warning event if hook script is not executable" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => "exit 1") { |file| file.chmod(0644)}
      Razor::Data::Hook.run('abc', node: Fabricate(:node))
      events = Razor::Data::Event.all
      events.size.should == 1
      events.first.entry['msg'].should =~ /abc is not executable/
      events.first.entry['cause'].should == 'abc'
      events.first.entry['severity'].should == 'warn'
    end

    # include TorqueBox::Injectors
    # let :queue do fetch('/queues/razor/sequel-instance-messages') end
    [[0, 'info'], [1, 'error']].each do |exitcode, severity|
      it "should create an #{severity} event if hook script exits with #{exitcode}" do
        hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

        set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "error": {
    "message": "some-bad-error",
    "extra": "details here"
  },
  "output": "standard output"
}
EOF
exit #{exitcode}
        CONTENTS
        Razor::Data::Hook.run('abc', node: node)
        queue.count_messages.should == 1
        run_message(queue.receive)
        event = Razor::Data::Event.find(hook_id: hook.id)
        event.node_id.should == node.id
        event.hook_id.should == hook.id
        event.entry['error'].should == {'message' => 'some-bad-error', 'extra' => 'details here'}
        event.entry['msg'].should == 'standard output'
        event.entry['cause'].should == 'abc'
        event.entry['severity'].should == severity

        Razor::Data::Event.count.should == 1
      end
    end
    it "should create an info event if hook script exits with 0" do
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "standard output"
}
EOF
exit 0
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      event = Razor::Data::Event.find(hook_id: hook.id)
      event.node_id.should == node.id
      event.hook_id.should == hook.id
      event.entry['msg'].should == 'standard output'
      event.entry['severity'].should == 'info'

      Razor::Data::Event.count.should == 1
    end
  end

  describe "input" do
    it "should supply essential details to the hook" do
      configuration = {
          'a'  => {'required' => false},
      }
      set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type, :configuration => {'a' => 'b'}).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

json=$(< /dev/stdin)

cat <<EOF
{
  "output": $json
}
EOF
      CONTENTS
      policy = Fabricate(:policy_with_tag)
      node = Fabricate(:bound_node, policy: policy, tags: policy.tags)
      Razor::Data::Hook.run('abc', node: node)

      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first
      run_message(event)

      event = Razor::Data::Event.find(hook_id: hook.id)
      event.node_id.should == node.id
      event.hook_id.should == hook.id
      event.entry['severity'].should == 'info'
      input = event.entry['msg']
      input['hook']['name'].should == hook.name
      input['hook']['type'].should == hook.hook_type.name
      input['hook']['cause'].should == 'abc'
      input['hook']['configuration'].should == hook.configuration
      input['hook']['configuration']['a'].should == 'b'
      input['policy']['name'].should == node.policy.name
      input['policy']['repo'].should == node.policy.repo.name
      input['policy']['task'].should == node.policy.task.name
      input['policy']['broker'].should == node.policy.broker.name
      input['policy']['enabled'].should == node.policy.enabled
      input['policy']['hostname_pattern'].should == node.policy.hostname_pattern
      input['policy']['tags'].count.should == node.policy.tags.count
      input['policy']['nodes']['count'].should == node.policy.nodes.count
      input['node']['name'].should == node.name
      input['node']['facts'].count.should == node.facts.count
      input['node']['metadata'].count.should == node.metadata.count
      input['node']['tags'].count.should == node.tags.count
    end

    it "should contain recent metadata if node or hook has changed" do
      configuration = {
          'a'  => {'required' => true},
      }
      set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type, :configuration => {'a' => 'b'}).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

json=$(< /dev/stdin)

cat <<EOF
{
  "output": $json
}
EOF
      CONTENTS
      node = Fabricate(:bound_node)
      Razor::Data::Hook.run('abc', node: node)

      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first

      # Add a policy to the event after it's already on the queue.
      node.modify_metadata({'update' => {'a' => 'b'}})
      # Modify the hook's configuration.
      hook.configuration['a'] = 'c'
      hook.save
      # Disable the policy.
      node.policy.set(enabled: false).save

      run_message(event)

      event = Razor::Data::Event.find(hook_id: hook.id)
      event.node_id.should == node.id
      event.hook_id.should == hook.id
      event.entry['severity'].should == 'info'
      input = event.entry['msg']
      input['hook']['name'].should == hook.name
      input['hook']['type'].should == hook.hook_type.name
      input['hook']['cause'].should == 'abc'
      input['hook']['configuration'].should == hook.configuration
      input['policy']['name'].should == node.policy.name
      input['policy']['enabled'].should == false
      input['policy']['nodes']['count'].should == node.policy.nodes.count
      input['node']['name'].should == node.name
      input['node']['metadata'].should == node.metadata
    end
    it "should use old node data if node has been deleted" do
      configuration = {
          'a'  => {'required' => true},
      }
      set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type, :configuration => {'a' => 'b'}).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

json=$(< /dev/stdin)

cat <<EOF
{
  "output": $json
}
EOF
      CONTENTS
      node = Fabricate(:bound_node)
      Razor::Data::Hook.run('abc', node: node, policy: node.policy)

      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first

      # Delete the node.
      node.destroy
      node.policy.reload # To update the node count.

      run_message(event)

      event = Razor::Data::Event.find(hook_id: hook.id)
      event.node_id.should == nil # Since the node was deleted.
      event.hook_id.should == hook.id
      event.entry['severity'].should == 'info'
      input = event.entry['msg']
      input['hook']['name'].should == hook.name
      input['hook']['type'].should == hook.hook_type.name
      input['hook']['cause'].should == 'abc'
      input['hook']['configuration'].should == hook.configuration
      input['policy']['name'].should == node.policy.name
      input['policy']['enabled'].should == node.policy.enabled
      input['policy']['nodes']['count'].should == node.policy.nodes.count
      input['node']['name'].should == node.name
      input['node']['metadata'].should == node.metadata
    end
  end

  describe "output" do
    [[0, 'success'], [1, 'failure']].each do |exit, success|
      it "should allow modifying the hook's configuration on #{success}" do
        configuration = {
            'counter'  => {'required' => true, 'description' => 'foo'},
            'version' => {'required' => false,  'description' => 'bar'}
        }
        set_hook_file('test', 'configuration.yaml' => configuration.to_yaml)
        hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type, :configuration => {'counter' => 0, 'version' => '1.0'}).save

        set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "hook": {
    "configuration": {
      "update": {
        "counter": 1
      },
      "remove": ["version"]
    }
  }
}
EOF
exit #{exit}
        CONTENTS
        hook.configuration['counter'].should == 0
        Razor::Data::Hook.run('abc')
        queue.count_messages.should == 1
        run_message(queue.receive)
        hook.reload
        hook.configuration['counter'].should == 1
        hook.configuration.keys.should_not include 'version'
        JSON.parse(Razor::Data::Event.first[:entry])['actions'].should ==
            'updating hook configuration: {"update"=>{"counter"=>1}, "remove"=>["version"]}'
      end
    end

    [[0, 'success'], [1, 'failure']].each do |exit, success|
      it "should allow modifying the node's metadata on #{success}" do
        Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

        set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "node": {
    "metadata": {
      "update": {
        "new-key": "new-value",
        "existing": "a-value"
      },
      "remove": [
        "to-remove"
      ]
    }
  }
}
EOF
exit #{exit}
        CONTENTS
        node.metadata = {'existing' => 'value', 'to-remove' => 'other-value'}
        node.save
        Razor::Data::Hook.run('abc', node: node)
        # There will also be a 'Node' message on the queue.
        messages = queue.count_messages.times.map {queue.receive}
        event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first
        run_message(event)
        node.reload
        node.metadata['new-key'].should == 'new-value'
        node.metadata['existing'].should == 'a-value'
        node.metadata.keys.should_not include 'to-remove'
        JSON.parse(Razor::Data::Event.first[:entry])['actions'].should ==
            'updating node metadata: {"update"=>{"new-key"=>"new-value", "existing"=>"a-value"}, "remove"=>["to-remove"]}'
      end
    end

    it "should allow clearing the node's metadata" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "node": {
    "metadata": {
      "clear": true
    }
  }
}
EOF
      CONTENTS
      node.metadata = {'existing' => 'value'}
      node.save
      Razor::Data::Hook.run('abc', node: node)
      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first
      run_message(event)
      node.reload
      node.metadata.should == {}
    end

    it "should report an error if output is not JSON" do
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
standard output
EOF
exit 0
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)

      event = Razor::Data::Event.find(hook_id: hook.id)
      event.node_id.should == node.id
      event.hook_id.should == hook.id
      event.entry['error'].should == 'invalid JSON returned from hook'
      event.entry['msg'].should == "standard output\n"
      event.entry['severity'].should == 'error'
    end

    it "should fail if there is no node to modify" do
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "node": {
    "metadata": {
      "update": {
        "new-key": "new-value",
        "existing": "a-value"
      },
      "remove": [
        "to-remove"
      ]
    }
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc')
      queue.count_messages.should == 1
      run_message(queue.receive)

      event = Razor::Data::Event.find(hook_id: hook.id)
      event.entry['error'].should == 'hook tried to update node metadata on a hook without a node'
      event.entry['severity'].should == 'error'
    end

    it "should fail if hook attempts unexpected metadata operation" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "node": {
    "metadata": {
      "do-other-thing": {
        "this": "that"
      }
    }
  }
}
EOF
      CONTENTS
      node.metadata = {'existing' => 'value'}
      node.save
      Razor::Data::Hook.run('abc', node: node)
      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first
      run_message(event)
      node.reload
      node.metadata.should == {'existing' => 'value'}
      Razor::Data::Event.first.entry['error'].should == 'unexpected node metadata operation(s) do-other-thing included'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid key" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "other-key": {
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == 'unexpected key in hook\'s output: other-key'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid node key" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "node": {
    "other-key": {
    }
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == 'unexpected key in hook\'s output for node update: other-key'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid hook key" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "hook": {
    "other-key": {
    }
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == 'unexpected key in hook\'s output for hook update: other-key'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid hook configuration key" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "hook": {
    "configuration": "abc"
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == 'hook output for hook configuration should be an object but was a string'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid hook configuration key" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "hook": {
    "configuration": "abc"
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == 'hook output for hook configuration should be an object but was a string'
      Razor::Data::Event.first.entry['severity'].should == 'warn'
      Razor::Data::Event.count.should == 1
    end

    it "should fail if hook returns invalid hook configuration operation" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save
      set_hook_file('test', 'abc' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "hook": {
    "configuration": {
      "do-thing": {
        "a": "c"
      }
    }
  }
}
EOF
      CONTENTS
      Razor::Data::Hook.run('abc', node: node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['error'].should == "undefined operation on hook: do-thing; should be 'update' or 'remove'"
      Razor::Data::Event.first.entry['severity'].should == 'error'
      Razor::Data::Event.count.should == 1
    end
  end
  describe "events" do
    it "should fire for node-registered" do
      Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'node-registered' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "it worked"
}
EOF
      CONTENTS
      Node.register('macaddress' => node.hw_info[0][4..1000])
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.first.entry['msg'].should == 'it worked'
    end
    it "should fire for node-bound-to-policy" do
      body = { "facts" => { "f1" => "1" } }

      node do
        n = Fabricate(:node)
        n.checkin(body)
        n
      end
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'node-bound-to-policy' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "it worked"
}
EOF
      CONTENTS
      Fabricate(:policy)

      Policy.bind(node)
      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.find(hook_id: hook.id).entry['msg'].should == 'it worked'
    end
    it "should fire for node-unbound-from-policy" do
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'node-unbound-from-policy' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "it worked"
}
EOF
      CONTENTS
      node = Fabricate(:bound_node)

      node.unbind
      # There will also be a 'Node' message on the queue.
      messages = queue.count_messages.times.map {queue.receive}
      event = messages.select {|message| message['class'] == 'Razor::Data::Hook'}.first
      run_message(event)
      Razor::Data::Event.find(hook_id: hook.id).entry['msg'].should == 'it worked'
    end
    it "should fire for node-deleted" do
      hook = Razor::Data::Hook.new(:name => 'test', :hook_type => hook_type).save

      set_hook_file('test', 'node-deleted' => <<-CONTENTS)
#! /bin/bash

cat <<EOF
{
  "output": "it worked"
}
EOF
      CONTENTS
      node.destroy

      queue.count_messages.should == 1
      run_message(queue.receive)
      Razor::Data::Event.find(hook_id: hook.id).entry['msg'].should == 'it worked'
    end
  end
end