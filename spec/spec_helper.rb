# -*- encoding: utf-8 -*-
require 'simplecov'
SimpleCov.start do
  %w{/spec/ .erb vendor/}.map {|f| add_filter f }
end

require 'fabrication'
require 'faker'

Dir.glob(File.join(File::dirname(__FILE__), 'shared_examples', '*.rb')).each {|f| require f }

require 'rack/test'
require 'json'
require 'timecop'

# This is provided inside TorqueBox, but is not available by default in our
# spec runner.  Without it some of our dependencies fail to load. :(
require_relative '../jars/slf4j-api-1.6.4.jar'


ENV["RACK_ENV"] ||= "test"

require_relative '../lib/razor/initialize'
require_relative '../lib/razor'

# Add some convenience functions to MockResponse
class Rack::MockResponse
  def mime_type
    content_type.split(";")[0]
  end

  def json?
    mime_type == "application/json"
  end

  def json
    parse_body if @json.nil?
    @json
  end

  def command
    if @command.nil?
      parse_body if @json.nil?
      if @command_url
        @command = Razor::Data::Command[@command_url.split('/').last]
      end
    end
    @command
  end

  private
  def parse_body
    @json = JSON::parse(body)
    @command_url = @json.delete('command')
  end
end

# Tests are allowed to changed config on the fly
class Razor::Config
  def []=(key, value)
    path = key.to_s.split(".")
    last = path.pop
    path.inject(@values) { |v, k| v[k] ||= {}; v[k] if v }[last] = value
  end

  def values
    @values
  end

  def values=(v)
    @values = v
  end

  def reset!
    @facts_blacklist_rx = nil
    @facts_match_on_rx = nil
    @values['match_nodes_on'] = Razor::Config::HW_INFO_KEYS
  end
end

FIXTURES_PATH = File::expand_path("fixtures", File::dirname(__FILE__))
INST_PATH = File::join(FIXTURES_PATH, "tasks")

BROKER_FIXTURE_PATH = File.join(FIXTURES_PATH, 'brokers')
HOOK_FIXTURE_PATH = File.join(FIXTURES_PATH, 'hooks')

def use_task_fixtures
  Razor.config["task_path"] = INST_PATH
end

def use_broker_fixtures
  Razor.config["broker_path"] = BROKER_FIXTURE_PATH
end

def use_hook_fixtures
  Razor.config["hook_path"] = HOOK_FIXTURE_PATH
end

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

# Make sure our migration is current, or fail hard.
Sequel.extension :migration
unless Sequel::Migrator.is_current?(Razor.database, File.join(File::dirname(__FILE__), '..', 'db', 'migrate'))
  puts <<EOT
Hey.  Your database migrations are not current!  Without them being at the
exact expected version you can expect all sorts of random looking failures.

You should rerun the migrations now.  That will fix things and stop this
error from getting in your way.  Enjoy.

EOT
  exit 1
end

# Restore the config after each test
RSpec.configure do |c|
  c.around(:each) do |example|
    config_values = Razor.config.values.dup
    Razor.config.reset!
    Razor.config['auth.config'] = File.expand_path('shiro.ini', File.dirname(__FILE__))
    Razor.config['auth.enabled'] = true
    example.run
    Razor.config.values = config_values
  end
end

# Roll DB back after each test
RSpec.configure do |c|
  c.around(:each) do |example|
    Razor.database.transaction(:rollback=>:always){example.run}
  end
end

# Provide some common infrastructure emulation for use across our test
# framework.  This provides enough messaging emulation that we can send
# messages in tests and capture the fact they were sent without worrying
# over-much.
require_relative 'lib/razor/fake_queue'
RSpec.configure do |c|
  c.before(:each) do
    TorqueBox::Registry.merge!(
      '/queues/razor/sequel-instance-messages' => Razor::FakeQueue.new,
      '/queues/razor/sequel-hooks-messages' => Razor::FakeQueue.new
    )
  end

  c.after(:each) do
    TorqueBox::Registry.registry.clear
  end
end

# @todo lutter 2013-11-15: this works around a bug in
# TorqueBox::FallbackLogger and should be removed once
# https://issues.jboss.org/browse/TORQUE-1177 has been fixed
class TorqueBox::FallbackLogger
  def flush
  end

  def write(message)
    info(message.strip)
  end
end

# Our own method(s) for testing commands. These will automatically include
# Rack::Test::Methods
module Razor::Test
  module Commands
    include Rack::Test::Methods

    # A helper to test commands. It translates the +name+ to the correct
    # command URL, and turns params into JSON
    #
    # If the command succeeds, check that the return code is 202, and that
    # an entry was made into the command log, and check its sanity
    def command(name, params, opts = {})
      post "/api/commands/#{name}", params.to_json
      status = (opts[:status] || 'finished').to_s
      if last_response.successful?
        last_response.status.should == 202
        last_response.command.should_not be_nil
        last_response.command.command.should == name.to_s
        cmd = Razor::Command.find(name: name)
        params = Hash[params.map{|(k,v)| [k.to_s,v]}]
        # Do the aliasing and conforming before checking the returned params.
        modified_params = cmd.conform!(cmd.apply_aliases!(params))
        # Overwrite with special nested hash values.
        modified_params = deep_merge(modified_params, opts[:expect]) if opts[:expect]
        last_response.command.params.should == stringify_keys(modified_params)
        last_response.command.status.should == status
      end
    end

    def stringify_keys(hash)
      hash.inject({}) do |memo, (key, value)|
        if value.is_a?(Hash)
          memo[key.to_s] = stringify_keys(value)
        else
          memo[key.to_s] = value
        end
        memo
      end
    end

    private
    # This method melds all values from `new` into `original` using the same
    # structure. `new` must be a hash or nested hash, otherwise will be ignored.
    # If there exists a value for `new`, it will clobber the corresponding value
    # in `original` unless both are hashes, in which case the items are merged.
    def deep_merge(original, new)
      merger = proc { |key,v1,v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      new.merge(original, &merger)
    end
  end
end

# Conveniences for dealing with model objects
Node   = Razor::Data::Node
Tag    = Razor::Data::Tag
Repo   = Razor::Data::Repo
Policy = Razor::Data::Policy
Broker = Razor::Data::Broker
Command= Razor::Data::Command
Hook   = Razor::Data::Hook
