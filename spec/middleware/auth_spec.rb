require 'spec_helper'
require 'rack/lobster'

# Until we have more than one messaging helper, this will do.
describe Razor::Middleware::Auth do
  include Rack::Test::Methods

  # This is a viable rack app, shipped with rack core, used as the underlying
  # application for testing our auth middleware.
  let :lobster do Rack::Lobster.new end

  [{}, [], [/foo/], 12, nil].each do |what|
    it "should raise if #{what.inspect} is given as a pattern" do
      expect {
        Razor::Middleware::Auth.new(lobster, what)
      }.to raise_error TypeError, /patterns/

      expect {
        Razor::Middleware::Auth.new(lobster, '/foo', what)
      }.to raise_error TypeError, /patterns/

      expect {
        Razor::Middleware::Auth.new(lobster, what, '/bar')
      }.to raise_error TypeError, /patterns/

      expect {
        Razor::Middleware::Auth.new(lobster, '/bar', what, '/foo')
      }.to raise_error TypeError, /patterns/
    end
  end

  context "with no patterns on create" do
    let :app do Razor::Middleware::Auth.new(lobster) end

    it "should return content with no authentication" do
      get '/'
      last_response.status.should == 200
    end

    it "should return content with correct authentication"do
      authorize "fred", "dead"
      get '/'
      last_response.status.should == 200
    end

    it "should 401 with an incorrect username" do
      authorize "joe", "dead"
      get '/'
      last_response.status.should == 200
    end

    it "should 401 with an incorrect password" do
      authorize "fred", "live"
      get '/'
      last_response.status.should == 200
    end
  end

  shared_examples "authenticate correctly" do |*patterns|
    let :app do Razor::Middleware::Auth.new(lobster, *patterns) end

    it "should 401 without authentication" do
      get "/with-auth/lobster"
      last_response.status.should == 401
    end

    it "should 401 with incorrect username" do
      authorize "joe", "dead"
      get "/with-auth/lobster"
      last_response.status.should == 401
    end

    it "should 401 with incorrect password" do
      authorize "fred", "live"
      get "/with-auth/lobster"
      last_response.status.should == 401
    end

    it "should return content with correct credentials" do
      authorize "fred", "dead"
      get "/with-auth/lobster"
      last_response.status.should == 200
    end

    it "should return content for non-protected paths without authentication" do
      get "/no-auth/lobster"
      last_response.status.should == 200
    end

    it "should return content for non-protected paths with correct authentication" do
      authorize "fred", "dead"
      get "/no-auth/lobster"
      last_response.status.should == 200
    end

    it "should 401 content on non-protected paths with an incorrect username" do
      authorize "joe", "dead"
      get "/with-auth/lobster"
      last_response.status.should == 401
    end

    it "should 401 content on non-protected paths with an incorrect password" do
      authorize "fred", "live"
      get "/with-auth/lobster"
      last_response.status.should == 401
    end
  end

  context "with regexp auth" do
    include_examples "authenticate correctly", %r{/with-auth}
  end

  context "with string auth" do
    include_examples "authenticate correctly", '/with-auth'
  end
end
