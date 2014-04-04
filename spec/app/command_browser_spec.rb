# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "command browser API" do
  include Rack::Test::Methods
  before :each do authorize 'fred', 'dead' end

  def app() Razor::App end

  # We want a command available for testing, unrelated to the default ones.
  let :cmd do Class.new(Razor::Command) end
  before :each do stub_const('Razor::Command::TestBrowsing', cmd) end

  def last_response
    begin
      r = super
    rescue Rack::Test::Error => e
      raise unless e.to_s =~ /No response yet. Request a page first/
      get '/api/commands/test-browsing'
      retry
    end
    r.status.should == 200
    r
  end

  it "should include an etag based on current razor version" do
    last_response.headers.find{|k,v| k.downcase == "etag" }[1].
      should =~ Regexp.new(Regexp.escape(Razor::VERSION))
  end

  it "should return json" do
    last_response.content_type.should =~ %r{application/json}
  end

  it "should return the command name" do
    last_response.json.should == {'name' => 'test-browsing'}
  end
end
