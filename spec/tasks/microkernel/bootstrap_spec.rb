# -*- encoding: utf-8 -*-
require_relative '../../spec_helper'
require_relative '../../../app'

describe "tasks/common/boot_local" do
  include Rack::Test::Methods
  def app; Razor::App end

  before :each do
    Razor.config['auth.enabled'] = false
  end
  after :each do
    Razor.config['secure_api'] = false
  end

  subject :boot_local do
    get "/api/microkernel/bootstrap"
    last_response.status.should == 200
    last_response.body
  end

  it "should set the number of tries" do
    boot_local.should =~ /set tries.*0/
  end

  context 'http_port' do
    after :each do
      ENV::store('HTTP_PORT', nil)
      Razor.config['secure_api'] = false
    end
    it "should allow secure bootstrap requests with http_port argument" do
      Razor.config['secure_api'] = true
      get "/api/microkernel/bootstrap?http_port=8001", {}, 'HTTPS' => 'on'
      last_response.status.should == 200
      last_response.body.should =~ /:8001\//
    end
    it "should allow insecure bootstrap requests with http_port argument" do
      Razor.config['secure_api'] = false
      ENV::store('HTTP_PORT', '8110')
      get "/api/microkernel/bootstrap?http_port=8002", {}, 'HTTPS' => 'off'
      last_response.status.should == 200
      last_response.body.should =~ /:8002\//
    end

    it "should use the http_port argument for insecure requests" do
      Razor.config['secure_api'] = false
      ENV::store('HTTP_PORT', '8110')
      get "/api/microkernel/bootstrap?http_port=8010", {}, 'HTTPS' => 'off'
      last_response.status.should == 200
      last_response.body.should =~ /:8010\//
    end

    it "should use the environment variable for HTTP_PORT" do
      Razor.config['secure_api'] = true
      ENV::store('HTTP_PORT', '8110')
      get "/api/microkernel/bootstrap", {}, 'HTTPS' => 'on'
      last_response.status.should == 200
      last_response.body.should =~ /:8110\//
    end

    it "should use the default of 8150 if not supplied for secure requests" do
      Razor.config['secure_api'] = true
      get "/api/microkernel/bootstrap", {}, 'HTTPS' => 'on'
      last_response.status.should == 200
      last_response.body.should =~ /:8150\//
    end

    it "should use the request port if not supplied for insecure requests" do
      Razor.config['secure_api'] = false
      get "/api/microkernel/bootstrap", {}, 'HTTPS' => 'off'
      last_response.status.should == 200
      last_response.body.should =~ /:80\//
    end

    it "should allow both the http_port argument and the nic_max argument" do
      Razor.config['secure_api'] = false
      get "/api/microkernel/bootstrap?http_port=8080&nic_max=4", {}, 'HTTPS' => 'off'
      last_response.status.should == 200
      last_response.body.should =~ /:8080\//
      4.times.each do |i|
        last_response.body.should =~ /^[^#]*dhcp\s+net#{i}/m
      end
    end

    ['-80', '65536', '6a', '0'].each do |value|
      it "should reject invalid http_port input: #{value}" do
        get "/api/microkernel/bootstrap?http_port=#{value}"
        last_response.status.should == 400
        last_response.json['error'].should ==
            'The http_port parameter must be an integer between 1 and 65535'
      end
    end
  end
end
