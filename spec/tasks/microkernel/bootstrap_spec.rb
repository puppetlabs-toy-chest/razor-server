# -*- encoding: utf-8 -*-
require_relative '../../spec_helper'
require_relative '../../../app'

describe "tasks/common/boot_local" do
  include Rack::Test::Methods
  def app; Razor::App end

  before :each do
    Razor.config['auth.enabled'] = false
  end

  subject :boot_local do
    get "/api/microkernel/bootstrap"
    last_response.status.should == 200
    last_response.body
  end

  it "should set the number of tries" do
    boot_local.should =~ /set tries.*0/
  end
end
