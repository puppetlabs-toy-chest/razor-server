# -*- encoding: utf-8 -*-
require 'spec_helper'

# Until we have more than one messaging helper, this will do.
describe Razor::Messaging::Sequel do
  include TorqueBox::Injectors

  subject(:handler) { Razor::Messaging::Sequel.new }
  let :queue do fetch('/queues/razor/sequel-instance-messages') end

  # A convenience for the awfully long name we otherwise have.
  MessageViolatesConsistencyChecks =
    ::Razor::Messaging::Sequel::MessageViolatesConsistencyChecks

  describe "find_instance_in_class" do
    it "should return nil if no instance is found" do
      # Ensure we don't just, say, return the first instance of an object
      # regardless of the input.
      saved = Fabricate(:repo)
      handler.find_instance_in_class(Razor::Data::Repo, { :name => 'nonesuch' }).
        should be_nil
    end

    it "should raise an error if the PK is not a map" do
      expect {
        handler.find_instance_in_class(Razor::Data::Repo, ['nonesuch'])
      }.to raise_error MessageViolatesConsistencyChecks
    end

    it "should raise if the PK is nil" do
      expect {
        handler.find_instance_in_class(Razor::Data::Repo, nil)
      }.to raise_error MessageViolatesConsistencyChecks
    end

    it "should return an instance if the object exists" do
      saved = Fabricate(:repo)
      # This may not be identity, but is equality.
      handler.find_instance_in_class(Razor::Data::Repo, saved.pk_hash).
        should == saved
    end
  end

  describe "find_razor_data_class" do
    [nil, 0, 0.0, 0.0/0.0, {}, []].each do |input|
      it "should fail because #{input.inspect} is not a string name" do
        expect {
          handler.find_razor_data_class(input)
        }.to raise_error MessageViolatesConsistencyChecks, /must be a string/
      end
    end

    %w[IO Process::Status Razor Razor::Task Razor::Util::TemplateConfig].each do |input|
      it "should fail because #{input.inspect} is not in the Razor::Data namespace" do
        expect {
          handler.find_razor_data_class(input)
        }.to raise_error MessageViolatesConsistencyChecks, /is not under Razor::Data namespace/
      end
    end

    it "should fail if the name isn't directly under Razor::Data" do
      expect {
        handler.find_razor_data_class("Razor::Data::Repo::Hack")
      }.to raise_error MessageViolatesConsistencyChecks, /is not under Razor::Data namespace/
    end

    it "should fail if the name isn't present" do
      expect {
        handler.find_razor_data_class("Razor::Data::")
      }.to raise_error MessageViolatesConsistencyChecks, /is not under Razor::Data namespace/
    end

    # Cyrillic upper-case E (the last test case) is not legal, even though it
    # is identical to ASCII.  Gotta love them homographs.  Added since someone
    # is bound to read the output, and wonder why that doesn't qualify. :)
    ['-Foo', 'foo', 'NoSuchClass', '3Com', "\u0194ager", "\u0415o"].each do |name|
      name = "Razor::Data::" + name
      it "should fail with the illegal or missing class name #{name.inspect}" do
        expect {
          handler.find_razor_data_class(name)
        }.to raise_error MessageViolatesConsistencyChecks, /is not a valid class name/
      end
    end

    [nil, 'foo', 0, 0.0, 0.0/0.0, {}, [], Module.new].each do |input|
      it "should fail if the constant is #{input.inspect}, not a class" do
        name = "Razor::Data::TestConstant"
        stub_const(name, input)
        expect {
          handler.find_razor_data_class(name)
        }.to raise_error MessageViolatesConsistencyChecks, /when Class was expected/
      end
    end

    it "should return the constant" do
      handler.find_razor_data_class("Razor::Data::Repo").should eq Razor::Data::Repo
    end
  end

  describe "find_command" do
    it "should fail when pk_hash is nil" do
      expect {
        handler.find_command(nil)
      }.to raise_error MessageViolatesConsistencyChecks, /when Hash was expected/
    end

    it "should fail when pk_hash has no id" do
      expect {
        handler.find_command({})
      }.to raise_error MessageViolatesConsistencyChecks, /must be a nonempty Hash/
    end

    it "should fail when the command is not found" do
      expect {
        handler.find_command({:id => 42})
      }.to raise_error MessageViolatesConsistencyChecks, /Razor::Data::Command with pk {:id=>42}/
    end

    it "should return the command" do
      command = Fabricate(:command)
      handler.find_command(command.pk_hash).should == command
    end
  end

  describe "update_body_with_exception" do
    # Having a real exception is better than trying to fake one, as some
    # attributes like the backtrace are filled in by the `raise` process, not
    # by creation of the exception object.
    let :exception do
      begin
        raise "first exception"
      rescue => e
        e
      end
    end

    let :second_exception do
      begin
        raise "second exception"
      rescue => e
        e
      end
    end

    let :message do
      {
        'class'     => 'Razor::Data::Repo',
        'instance'  => {'name' => 'pecan pie'},
        'message'   => 'test_message',
        'arguments' => [1, 3, 2]
      }
    end

    it "should default to zero retries" do
      body = handler.update_body_with_exception({}, exception)
      body.should include "retries"
      body["retries"].should == 1
    end

    it "should increment existing retries" do
      body = handler.update_body_with_exception({"retries" => 12}, exception)
      body.should include "retries"
      body["retries"].should == 13
    end

    it "should add a new exception in an array" do
      body = handler.update_body_with_exception({}, exception)
      body.should include "exceptions"
      body["exceptions"].should be_an_instance_of Array
      body["exceptions"].should have(1).exception
    end

    it "should unpack the exception" do
      body = handler.update_body_with_exception({}, exception)
      body['exceptions'][0].should == {
        'exception' => exception.class.name,
        'message'   => exception.to_s,
        'backtrace' => exception.backtrace
      }
    end

    it "should add the exception at the end of the array" do
      body = handler.update_body_with_exception({},   exception)
      body = handler.update_body_with_exception(body, second_exception)
      body["exceptions"].should have(2).exceptions

      body["exceptions"][0]['message'].should == 'first exception'
      body["exceptions"][1]['message'].should == 'second exception'
    end

    it "should pass through other attributes unmodified" do
      body = handler.update_body_with_exception(message, exception)
      body.should include message
    end

    it "should augment a frozen message correctly" do
      body = handler.update_body_with_exception(message.freeze, exception)
      body.should include message
    end
  end

  describe "delay_for_retry" do
    context "with a fixed PRNG" do
      let :prng do Random.new(755419531) end

      {  1 =>  0.34, 2 =>  0.34, 3 =>  1.7, 4 => 4.42, 5  =>   4.42,
         6 =>  4.42, 7 => 26.18, 8 => 69.7, 9 => 69.7, 10 => 243.78,
        11 => 243.78,
      }.each do |input, result|
        it "should return #{result} for #{input} retries given a fixed PRNG" do
          handler.delay_for_retry(input, prng).should == result
        end
      end
    end

    context "statistically" do
      # This is a large enough count that, given this nicely fixed PRNG, we
      # get solid results without spending too long on them.  In a profile of
      # all tests, the a round is visible, but low compared to other tests.
      #
      # We can drop down to 2500 rounds if we accept retry_count * 0.25 as the
      # margin for error, should this prove too optimistic an estimate.
      #
      # Alternately, we can gate this on, eg, ENV['SLOW_TESTS'] being set, and
      # raise the round count, to get firmer confirmation that the code works.
      let :count do 5000 end
      let :prng  do Random.new(2043023142) end

      (1..15).each do |retry_count|
        max_wait = (((2 ** [retry_count, 10].min) - 1) * 0.34).round(2)
        avg_wait = (max_wait / 2).round(2)
        it "retry #{retry_count.to_s.rjust(2)} should be >= 0, <= #{'%6.2f' % max_wait}, and average around #{'%6.2f' % avg_wait}" do
          values  = (1..count).map {|x| handler.delay_for_retry(retry_count, prng) }
          values.max.should be <= max_wait
          values.min.should be >= 0

          average = values.inject(0) {|sum, value| sum + value } / count
          # Accept more error as our values grow larger; this is a harsh
          # reality of the low round count for the statistical test.
          average.should be_within(retry_count * 0.2).of(avg_wait)
        end
      end
    end
  end

  describe "process!" do
    def message(body)
      message = double('TorqueBox::Messaging::Message')
      message.stub('decode').and_return(body)
      message.stub('getJMSMessageID').and_return('ID:91ac3a0a-eb15-11e2-bf31-9d8028fb14ed')
      message                   # sigh.
    end

    it "should not queue any messages if there is no body" do
      handler.process!(message(nil))
      queue.count_messages.should == 0
    end

    it "should not queue any messages if the body is empty" do
      handler.process!(message(''))
      queue.count_messages.should == 0
    end

    it "should not queue any messages if the Ruby message is missing" do
      handler.process!(message({}))
      queue.count_messages.should == 0
    end

    it "should fail the message if the instance is not found" do
      cmd = Fabricate(:command)
      content = {
        'class'     => 'Razor::Data::Repo',
        'instance'  => {'name' => 'nonesuch'},
        'message'   => 'to_s',
        'arguments' => [],
        'command'   => { :id => cmd.id }
      }

      standpoint = Time.at(-771939039) # whatever
      Time.stub(:now).and_return(standpoint)

      handler.process!(message(content))
      cmd.reload
      cmd.status.should == 'failed'
      queue.count_messages.should == 0
    end

    it "should not queue a retry if the instance is found" do
      pk = Fabricate(:repo).pk_hash
      content = {
        'class'     => 'Razor::Data::Repo',
        'instance'  => pk,
        'message'   => 'to_s',
        'arguments' => []
      }

      handler.process!(message(content))
      queue.should == []
    end

    it "should not queue a retry if the command is not found" do
      pk = Fabricate(:repo).pk_hash
      content = {
        'class'     => 'Razor::Data::Repo',
        'instance'  => pk,
        'command'   => { :id => 42 },
        'message'   => 'to_s',
        'arguments' => []
      }

      handler.process!(message(content))
      queue.should == []
    end

    it "should queue a retry if the command throws an exception" do
      pk = Fabricate(:repo).pk_hash
      cmd = Fabricate(:command)
      content = {
          'class'     => 'Razor::Data::Repo',
          'instance'  => pk,
          'command'   => { :id => cmd.id },
          'message'   => 'unpack_repo',
          'arguments' => ["doesnt-exist"]
      }

      expect { handler.process!(message(content)) }.
          to have_published(content).on(queue)
    end

    it "should deliver the message if 'arguments' is missing" do
      pk = Fabricate(:repo).pk_hash
      content = {
        'class'     => 'Razor::Data::Repo',
        'instance'  => pk,
        'message'   => 'to_s',
      }

      handler.process!(message(content))
      queue.should == []
    end

    it "should deliver the message if 'arguments' is nil" do
      pk = Fabricate(:repo).pk_hash
      content = {
        'class'     => 'Razor::Data::Repo',
        'instance'  => pk,
        'message'   => 'to_s',
        'arguments' => nil
      }

      handler.process!(message(content))
      queue.should == []
    end
  end

  describe "Sequel::Model#publish" do
    subject(:repo) do
      repo = Fabricate(:repo)
      queue.remove_messages # saving produces messages, which we are not testing.
      repo
    end

    [1, Object.method(:to_s), Object.new].each do |message|
      it "should fail if the message is a #{message.class}" do
        stub_const("Razor::Data::Test", Class.new(Sequel::Model))
        expect {
          repo.publish(message)
        }.to raise_error TypeError, /where String or Symbol was expected/
      end
    end

    it "should fail if the instance does not respond to the message" do
      expect {
        repo.publish('no_method_exists_by_this_name')
      }.to raise_error NameError, /undefined method/
    end

    it "should fail if the message has variable arity" do
      repo.instance_eval <<EOT
def variable_arity(one, two, *rest)
  true
end
EOT
      expect {
        repo.publish('variable_arity', 1, 2, 3, 4)
      }.to raise_error ArgumentError, /variable number of arguments/
    end

    it "should fail if the message takes optional arguments" do
      repo.instance_eval <<EOT
def optional_argument(one, two = 2)
  true
end
EOT
      expect {
        repo.publish('optional_argument', 1)
      }.to raise_error ArgumentError, /variable number of arguments/

      expect {
        repo.publish('optional_argument', 1, 2)
      }.to raise_error ArgumentError, /variable number of arguments/
    end

    it "should fail if too few arguments are passed" do
      expect {
        repo.publish('set')
      }.to raise_error ArgumentError, /wrong number of arguments/
    end

    it "should fail if too many arguments are passed" do
      expect {
        repo.publish('to_s', 1)
      }.to raise_error ArgumentError, /wrong number of arguments/
    end

    it "should fail if a block is given" do
      expect {
        repo.publish('to_s') { true }
      }.to raise_error ArgumentError, /blocks cannot be published/
    end

    it "should publish the message" do
      repo.publish('to_s')
      queue.count_messages.should == 1
    end

    context "message format" do
      context "no arguments" do
        subject do
          repo.publish('to_s')
          queue.receive
        end

        its(["class"])     { should == repo.class.name }
        its(["instance"])  { should == repo.pk_hash }
        its(["message"])   { should == 'to_s' }
        its(["arguments"]) { should == [] }
        its(["command"])   { should be_nil }
      end

      # Test the special behavior of 'publish' when the first
      # argument is a Razor::Data::Command
      context "publish with command" do
        let(:command) { Fabricate(:command) }
        subject do
          def repo.to_s_with_command(command)
            to_s
          end
          repo.publish('to_s_with_command', command)
          queue.receive
        end

        its(["class"])     { should == repo.class.name }
        its(["instance"])  { should == repo.pk_hash }
        its(["message"])   { should == 'to_s_with_command' }
        its(["arguments"]) { should == [] }
        its(["command"])   { should == command.pk_hash }
      end

      context "complex arguments" do
        let :symbol do :test  end
        let :string do "test" end
        let :number do -1.2 end

        let :hash do
          {
            :true     => true,
            :false    => false,
            'string'  => 'string',
            'symbol'  => :symbol,
            :symbol   => 'symbol',
            'array'   => :array,
            ['array'] => 'array'
          }
        end

        let :array do
          [hash, symbol, string, number, -1, true, false]
        end

        subject do
          repo.instance_eval <<EOT
def complex_message(hash, array, symbol, string, number); end
EOT
          repo.publish('complex_message', hash, array, symbol, string, number)
          queue.receive
        end

        its(["class"])     { should == repo.class.name }
        its(["instance"])  { should == repo.pk_hash }
        its(["message"])   { should == 'complex_message' }
        its(["arguments"]) { should == [hash, array, symbol, string, number] }
      end
    end
  end
end
