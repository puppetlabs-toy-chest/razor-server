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

  it "should disallow secure bootstrap requests without http_port argument" do
    Razor.config['secure_api'] = true
    get "/api/microkernel/bootstrap", {}, 'HTTPS' => 'on'
    last_response.status.should == 400
    last_response.json['error'].should ==
        'The `http_port` argument must be supplied for bootstrap generation on a secure port'
  end

  it "should allow secure bootstrap requests with http_port argument" do
    Razor.config['secure_api'] = true
    get "/api/microkernel/bootstrap?http_port=8150", {}, 'HTTPS' => 'on'
    last_response.status.should == 200
    last_response.body.should =~ /:8150/
  end

  it "should use the http_port argument for insecure requests" do
    Razor.config['secure_api'] = false
    get "/api/microkernel/bootstrap?http_port=8150", {}, 'HTTPS' => 'off'
    last_response.status.should == 200
    last_response.body.should =~ /:8150/
  end
end
