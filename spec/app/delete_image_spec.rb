require_relative '../spec_helper'
require_relative '../../app'

describe "delete-image" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  def delete_image(name)
    post '/api/commands/delete-image', { "name" => name }.to_json
  end

  context "/api/commands/delete-image" do
    before :each do
      header 'content-type', 'application/json'
    end

    it "should delete an existing image" do
      img = Fabricate(:image)
      count = Image.count
      delete_image(img.name)

      last_response.status.should == 202
      Image[:id => img.id].should be_nil
      Image.count.should == count-1
    end

    it "should succeed and do nothing for a nonexistent image" do
      img = Fabricate(:image)
      count = Image.count

      delete_image(img.name + "not really")

      last_response.status.should == 202
      Image.count.should == count
    end
  end
end
