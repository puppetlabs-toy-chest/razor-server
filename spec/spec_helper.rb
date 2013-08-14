require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
  add_filter ".erb"
end

require 'rack/test'
require 'json'

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
    JSON::parse(body)
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
end

FIXTURES_PATH = File::expand_path("fixtures", File::dirname(__FILE__))
INST_PATH = File::join(FIXTURES_PATH, "installers")

def use_installer_fixtures
  Razor.config["installer_path"] = INST_PATH
end

# Restore the config after each test
RSpec.configure do |c|
  c.around(:each) do |example|
    config_values = Razor.config.values.dup
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
      '/queues/razor/sequel-instance-messages' => Razor::FakeQueue.new
    )
  end

  c.after(:each) do
    TorqueBox::Registry.registry.clear
  end
end

# Conveniences for dealing with model objects
Node = Razor::Data::Node
Tag = Razor::Data::Tag
Image = Razor::Data::Image
Policy = Razor::Data::Policy

def make_image(attr = {})
  h = {
    :name      => "dummy",
    :image_url => 'file:///dev/null'
  }
  h.merge!(attr)
  Image.create(h)
end

def make_policy(attr = {})
  h = {
    :name => "p1",
    :enabled => true,
    :installer_name => "some_os",
    :hostname_pattern => "host${id}.example.org",
    :root_password => "secret",
    :line_number => 100
  }
  h.merge!(attr)
  h[:image] ||= make_image
  Policy.create(h.merge(attr))
end
