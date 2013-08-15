require_relative '../spec_helper'
require_relative '../../app'

require 'json-schema'

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
      data["commands"].all? {|x| x.keys.should =~ %w[id rel name]}
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
        post row["id"]
        # The positive assertion captures cases where we incorrectly accept
        # the unknown content type; they shouldn't happen, but it beats out a
        # false positive.
        last_response.status.should == 415
      end
      data["collections"].all? do |row|
        get row["id"]
        last_response.status.should == 200
      end
    end
  end

  context "/api/collections/policies - policy list" do

    # `before` is used instead of `let` since the database gets rolled
    # back after every test
    before(:each) do
      use_installer_fixtures

      @node = Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
      @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
      @image = Fabricate(:image)
    end

    it "should return JSON content" do
      get '/api/collections/policies'
      last_response.status.should == 200
      last_response.content_type.should =~ /application\/json/i
    end

    it "should list all policies" do
      pl =  Fabricate(:policy, :image => @image, :installer_name => "some_os")
      pl.add_tag @tag

      get '/api/collections/policies'
      data = last_response.json
      data.size.should be 1
      data.all? do |policy|
        policy.keys.should =~ %w[id name spec]
      end
    end
  end

  context "/api/collections/policies/ID - get policy" do
    before(:each) do
      use_installer_fixtures

      @node = Razor::Data::Node.create(:hw_id => "abc", :facts => { "f1" => "a" })
      @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
      @image = Fabricate(:image)
    end

    subject(:pl){ Fabricate(:policy, :image => @image, :installer_name => "some_os")}

    it "should exist" do
      get "/api/collections/policies/#{URI.escape(pl.name)}"
      last_response.status.should be 200
    end

    it "should have the right keys" do
      get "/api/collections/policies/#{URI.escape(pl.name)}"
      policy = last_response.json

      policy.keys.should =~ %w[name id spec configuration enabled line_number max_count image tags]
      policy["image"].keys.should =~ %w[id name spec]
      policy["configuration"].keys.should =~ %w[hostname_pattern root_password]
      policy["tags"].should be_empty
      policy["tags"].all? {|tag| tag.keys.should =~ %w[spec url obj_id name] }
    end
  end

  context "/api/collections/tags - tag list" do
    it "should return JSON content" do
      get '/api/collections/tags'
      last_response.status.should == 200
      last_response.content_type.should =~ /application\/json/
    end

    it "should list all tags" do
      t = Razor::Data::Tag.create(:name=>"tag 1", :matcher =>Razor::Matcher.new(["=",["fact","one"],"1"]))
      get '/api/collections/tags'
      data = last_response.json
      data.size.should be 1
      data.all? do |tag|
        tag.keys.should =~ %w[id name spec]
      end
    end
  end

  context "/api/collections/tags/ID - get tag" do
    subject(:t) {Razor::Data::Tag.create(:name=>"tag_1", :rule => ["=",["fact","one"],"1"])}

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
      img1 = Fabricate(:image, :name => "image1")
      img2 = Fabricate(:image, :name => "image2")

      get "/api/collections/images"
      last_response.status.should == 200

      imgs = last_response.json
      imgs.size.should == 2
      imgs.map { |img| img["name"] }.should =~ %w[ image1 image2 ]
      imgs.all? { |img| img.keys.should =~ %w[id name spec] }
    end
  end

  context "/api/collections/images/:name" do
    it "should find image by name" do
      img1 = Fabricate(:image, :name => "image1")

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

  context "/api/collections/brokers" do
    BrokerCollectionSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Broker Collection JSON Schema",
      'type'     => 'array',
      'items'    => {
        '$schema'  => 'http://json-schema.org/draft-04/schema#',
        'type'     => 'object',
        'additionalProperties' => false,
        'properties' => {
          "spec" => {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type'    => 'string',
            'pattern' => '^https?://'
          },
          "id" => {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type'    => 'string',
            'pattern' => '^https?://'
          },
          "obj_id" => {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type'    => 'number'
          },
          "name" => {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type'    => 'string',
            'pattern' => '^[^\n]+$'
          }
        }
      }
    }.freeze

    BrokerItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Broker Collection JSON Schema",
      'type'     => 'object',
      'required' => %w[spec id name configuration broker_type],
      'properties' => {
        'spec' => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'id'       => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'name'     => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^[a-zA-Z0-9 ]+$'
        },
        'broker_type' => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^[a-zA-Z0-9 ]+$'
        },
        'configuration' => {
          '$schema' => 'http://json-schema.org/draft-04/schema#',
          'type'    => 'object',
          'additionalProperties' => {
            '$schema'   => 'http://json-schema.org/draft-04/schema#',
            'oneOf'     => [
              {
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type'      => 'string',
                'minLength' => 1
              },
              {
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type'      => 'number',
              }
            ]
          }
        }
      },
      'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    shared_examples "a broker collection" do |expected|
      before :each do
        Razor.config['broker_path'] =
          (Pathname(__FILE__).dirname.parent + 'fixtures' + 'brokers').realpath.to_s
      end

      it "should return a valid broker response empty set" do
        get "/api/collections/brokers"

        last_response.status.should == 200
        last_response.json.should be_an_instance_of Array
        last_response.json.count.should == expected
        validate! BrokerCollectionSchema, last_response.body
      end

      it "should 404 a broker requested that does not exist" do
        get "/api/collections/brokers/fast%20freddy"
        last_response.status.should == 404
      end

      if expected > 0
        it "should be able to access all broker instances" do
          Razor::Data::Broker.all.each do |broker|
            get "/api/collections/brokers/#{URI.escape(broker.name)}"
            last_response.status.should == 200
            validate! BrokerItemSchema, last_response.body
          end
        end
      end
    end

    context "with none" do
      it_should_behave_like "a broker collection", 0
    end

    context "with one" do
      before :each do
        Fabricate(:broker)
      end

      it_should_behave_like "a broker collection", 1
    end

    context "with ten" do
      before :each do
        10.times { Fabricate(:broker) }
      end

      it_should_behave_like "a broker collection", 10
    end
  end
end
