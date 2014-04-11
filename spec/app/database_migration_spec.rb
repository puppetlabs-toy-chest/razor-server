# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "database migration checks" do
  include Razor::Test::Commands

  let(:app)  { Razor::App }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  it "should fail if the migrations are not up to date" do
    Razor.database[:schema_info].update(:version => 3)
    get '/api'
    last_response.body.should =~ /razor-admin migrate-database/
    last_response.content_type.should =~ %r{text/plain}
    last_response.status.should == 500
  end
end
