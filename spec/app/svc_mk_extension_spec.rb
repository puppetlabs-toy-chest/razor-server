# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "/svc/mk/extension.zip" do
  include Rack::Test::Methods
  let :app do Razor::App end
  let :zip do (Pathname(__FILE__).dirname + '../fixtures/empty.zip').to_s end
  let :iso do (Pathname(__FILE__).dirname + '../fixtures/iso/tiny.iso').to_s end

  it "should 404 if no source is configured" do
    Razor.config['microkernel.extension-zip'] = nil
    get '/svc/mk/extension.zip'
    last_response.status.should == 404
  end

  it "should return if a zip file is configured" do
    Razor.config['microkernel.extension-zip'] = zip
    get '/svc/mk/extension.zip'
    last_response.status.should == 200
    last_response.content_type.should == 'application/zip'
    last_response.body.should == File.new(zip, 'rb').read
  end

  # This verifies that we don't do any content type inspection on the file.
  # That seems the most reasonable -- the MK client will handle any mismatch
  # of content type vs actual content anyway, so... yeah.
  it "should return a file that isn't zip content" do
    Razor.config['microkernel.extension-zip'] = iso
    get '/svc/mk/extension.zip'
    last_response.status.should == 200
    last_response.content_type.should == 'application/zip'
    last_response.body.should == File.new(iso, 'rb').read
  end
end
