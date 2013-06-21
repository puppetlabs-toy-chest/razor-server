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

RSpec.configure do |c|
  c.around(:each) do |example|
    Razor.database.transaction(:rollback=>:always){example.run}
  end
end

# Conveniences for dealing with model objects
Node = Razor::Data::Node
Tag = Razor::Data::Tag
Image = Razor::Data::Image
Policy = Razor::Data::Policy

def make_image(attr = {})
  h = {
    :name => "dummy",
    :type => "os",
    :path => "/dev/null"
  }
  h.merge!(attr)
  Image.create(h)
end
