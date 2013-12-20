require_relative '../spec_helper'
require_relative '../../app'

describe "application authentication" do
  include Rack::Test::Methods

  let :app do
    Razor::App
  end

  context "with auth enabled" do
    before :each do
      Razor.config['auth.enabled'] = true
    end

    it "should 401 if the credentials are missing" do
      get '/api'
      last_response.status.should == 401
    end

    it "should 401 if the credentials are supplied but user does not exist" do
      authorize 'jane', 'jungle'
      get '/api'
      last_response.status.should == 401
    end

    it "should 401 if the credentials are supplied but the password is wrong" do
      authorize 'fred', 'jungle'
      get '/api'
      last_response.status.should == 401
    end
  end

  context "with auth disabled" do
    before :each do
      Razor.config['auth.enabled'] = false
    end

    it "should work if the credentials are missing" do
      get '/api'
      last_response.status.should == 200
    end


    it "should 200 if the credentials are supplied but user does not exist" do
      authorize 'jane', 'jungle'
      get '/api'
      last_response.status.should == 200
    end

    it "should 200 if the credentials are supplied but the password is wrong" do
      authorize 'fred', 'jungle'
      get '/api'
      last_response.status.should == 200
    end
  end
end
