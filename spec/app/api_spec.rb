require_relative '../spec_helper'
require_relative '../../app'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  context "/ - API navigation index" do
    %w[text/plain text/html text/* application/js].each do |type|
      it "should reject #{type.inspect} content requests" do
        header 'Accept', type
        get '/api'
        last_response.status.should == 406
      end
    end

    it "should return JSON content" do
      get '/api'
      last_response.content_type.should =~ /application\/json/i
    end

    it "should match the shape of our command handler" do
      get '/api'
      data = last_response.json
      data.keys.should =~ %w[commands collections]
      data["commands"].all? {|x| x.keys.should =~ %w[rel url]}
    end

    it "should contain all valid URLs" do
      get '/api'
      data = JSON.parse(last_response.body)
      data["commands"].all? do |row|
        # An invariant of our command support is that they reject anything
        # other than application/json in the body, which we can take advantage
        # of here: by knowing the failure mode, we can tell "missing" from
        # "exists but refuses us service" safely.
        header 'content-type', 'text/x-unknown-binary-blob'
        post row["url"]
        # The positive assertion captures cases where we incorrectly accept
        # the unknown content type; they shouldn't happen, but it beats out a
        # false positive.
        last_response.status.should == 415
      end
      data["collections"].all? do |row|
        get row["url"]
        last_response.status.should == 200
      end
    end
  end

  context "/api/collections/policies - policy list" do

    # `before` is used instead of `let` since the database gets rolled
    # back after every test
    before(:each) do
      @node = Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
      @tag = Razor::Data::Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
      @image = make_image
    end

    it "should return JSON content" do
      get '/api/collections/policies'
      last_response.content_type.should =~ /application\/json/i
    end

    it "should list all policies" do
      pl =  make_policy(:image => @image, :installer_name => "dummy")
      pl.add_tag @tag

      get '/api/collections/policies'
      data = last_response.json
      data.size.should be 1
      data.all? do |policy|
        policy.keys.should =~ %w[name obj_id spec url]
      end
    end
  end

  context "/api/collections/policies/ID - get policy" do
    before(:each) do
      @node = Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
      @tag = Razor::Data::Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
      @image = make_image
    end

    subject(:pl){make_policy(:image => @image, :installer_name => "dummy")}

    it "should exist" do
      get "/api/collections/policies/#{pl.name}"
      last_response.status.should be 200
    end

    it "should have the right keys" do
      get "/api/collections/policies/#{pl.name}"
      policy = last_response.json

      policy.keys.should =~ %w[name id spec configuration enabled sort_order max_count image tags]
      policy["image"].keys.should =~ %w[name obj_id spec url]
      policy["configuration"].keys.should =~ %w[hostname_pattern domain_name root_password]
      policy["tags"].should be_empty
      policy["tags"].all? {|tag| tag.keys.should =~ %w[spec url obj_id name] }
    end
  end

  context "/api/collections/tags - tag list" do
    it "should return JSON content" do
      get '/api/tags'
      last_response.content_type.should =~ /application\/json/
    end

    it "should list all tags" do
      t = Razor::Data::Tag.create(:name=>"tag 1", :matcher =>Razor::Matcher.new(["=",["fact","one"],"1"]))
      get '/api/collections/tags'
      data = last_response.json
      data.size.should be 1
      data.all? do |tag|
        tag.keys.should =~ %w[spec obj_id name url]
      end
    end
  end

  context "/api/collections/tags/ID - get tag" do
    subject(:t) {Razor::Data::Tag.create(:name=>"tag_1", :matcher =>Razor::Matcher.new(["=",["fact","one"],"1"]))}

    it "should exist" do
      get "/api/collections/tags/#{t.name}"
      last_response.status.should be 200
    end

    it "should have the right keys" do
      get "/api/collections/tags/#{t.name}"
      tag = last_response.json
      tag.keys.should =~ %w[ spec id name matcher ]
      tag["matcher"].should == {"rule" => ["=",["fact","one"],"1"] }
    end
  end

  context "/api/collections/images" do
    it "should list all images" do
      img1 = make_image(:name => "image1")
      img2 = make_image(:name => "image2")

      get "/api/collections/images"
      last_response.status.should == 200

      imgs = last_response.json
      imgs.size.should == 2
      imgs.map { |img| img["name"] }.should =~ %w[ image1 image2 ]
      imgs.all? { |img| img.keys.should =~ %w[spec obj_id name url] }
    end
  end

  context "/api/collections/images/:name" do
    it "should find image by name" do
      img1 = make_image(:name => "image1")

      get "/api/collections/images/#{img1.name}"
      last_response.status.should == 200

      data = last_response.json
      data.keys.should =~ %w[spec id name image_url]
    end

    it "should return 404 when image not found" do
      get "/api/collections/images/not_an_image"
      last_response.status.should == 404
    end
  end

  context "/api/collections/installers/:name" do
    before(:each) do
      use_installer_fixtures
    end

    ROOT_KEYS = %w[spec id name os description boot_seq]
    OS_KEYS = %w[name version]

    it "works for file-based installers" do
      get "/api/collections/installers/some_os"
      last_response.status.should == 200

      data = last_response.json
      data.keys.should =~ ROOT_KEYS
      data["name"].should == "some_os"
      data["os"].keys.should =~ OS_KEYS
      data["boot_seq"].keys.should =~ %w[1 2 default]
      data["boot_seq"]["2"].should == "boot_again"
    end

    it "works for DB-backed installers" do
      inst = Razor::Data::Installer.create(:name => 'dbinst',
                                           :os => 'SomeOS',
                                           :os_version => '6',
                                           :boot_seq => { 1 => "install",
                                                          "default" => "local"})
      get "/api/collections/installers/dbinst"
      last_response.status.should == 200

      data = last_response.json
      data.keys.should =~ ROOT_KEYS
      data["name"].should == "dbinst"
      data["os"].keys.should =~ OS_KEYS
      data["boot_seq"].keys.should =~ %w[1 default]
    end
  end
end
