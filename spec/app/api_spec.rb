require_relative '../spec_helper'
require_relative 'siren_helper'
require_relative '../../app'

require 'json-schema'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  def class_url(path)
    "http://api.puppetlabs.com/razor/v1/class/#{path}"
  end

  context "/ - API navigation index" do
    %w[text/plain text/html text/* application/js].each do |type|
      it "should reject #{type.inspect} content requests" do
        header 'Accept', type
        get '/api'
        last_response.status.should == 406
      end
    end

    it "should return JSON Siren content" do
      get '/api'
      last_response.status.should == 200
      is_valid_siren?(last_response).should == true
    end

    it "should match the shape of our command handler" do
      get '/api'
      data = last_response.json
      data.keys.should =~ %w[actions class entities]

      data["actions"].all? { |x| x.keys.should =~ %w[href class name] }
    end

    it "should contain all valid URLs" do
      get '/api'
      data = JSON.parse(last_response.body)
      data["actions"].all? do |row|
        # An invariant of our command support is that they reject anything
        # other than application/json in the body, which we can take advantage
        # of here: by knowing the failure mode, we can tell "missing" from
        # "exists but refuses us service" safely.
        header 'content-type', 'text/x-unknown-binary-blob'
        post row["href"]
        # The positive assertion captures cases where we incorrectly accept
        # the unknown content type; they shouldn't happen, but it beats out a
        # false positive.
        last_response.status.should == 415
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

    it "should return a JSON Siren list of policies" do
      get '/api/collections/policies'
      last_response.status.should == 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("collection"), class_url("policy")]
    end

    it "should list all policies" do
      pl =  Fabricate(:policy, :image => @image, :installer_name => "some_os")
      pl.add_tag @tag

      get '/api/collections/policies'
      data = last_response.json
      data["entities"].all? do |policy|
        policy.keys.should include "href"
        policy["properties"].keys.should =~ %w[name]
      end
    end

    it "should have actions for policies" do
      get '/api/collections/policies'
      last_response.json["actions"].map{|a| a["name"]}.should =~ %w[create]
    end

    describe "'create' action" do
      subject(:create) do
        get '/api/collections/policies'
        last_response.json["actions"].find {|act| act["name"]=="create" }
      end

      it do
        create["fields"].map{|f| f["name"]}.should =~ %w[name image-name installer-name
          hostname root-password enabled line-number broker-name]
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

    it "should return a JSON Siren policy" do
      get "/api/collections/policies/#{URI.escape(pl.name)}"
      last_response.status.should be 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("policy")]
    end

    it "should have the right keys" do
      get "/api/collections/policies/#{URI.escape(pl.name)}"
      policy = last_response.json

      properties, subentities = policy.values_at "properties", "entities"
      properties.keys.should =~ %w[name configuration enabled line_number max_count]
      properties["configuration"].keys.should =~ %w[hostname_pattern root_password]

      image = policy["entities"].find {|ent| ent["rel"].first.end_with? "image"}
      tags = policy["entities"].find {|ent| ent["rel"].first.end_with? "tags"}

      image["properties"].keys.should =~ ["name"]
      tags["entities"].should be_empty
    end
  end

  context "/api/collections/tags - tag list" do
    let! (:t) {Razor::Data::Tag.create(:name=>"tag 1", :rule =>["=",["fact","one"],"1"]) }

    it "should return a JSON Siren list of tags" do
      get '/api/collections/tags'
      last_response.status.should == 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("collection"), class_url("tag")]
    end

    it "should list all tags" do
      get '/api/collections/tags'
      data = last_response.json
      data["entities"].size.should be 1
      data["entities"].first["properties"]["name"].should == t.name
    end

    it "should have actions for tags" do
      get '/api/collections/tags'
      last_response.json["actions"].map{|a| a["name"]}.should =~ %w[create]
    end

    describe "'create' action" do
      subject(:create) do
        get '/api/collections/tags'
        last_response.json["actions"].find {|act| act["name"]=="create" }
      end

      it do
        create["fields"].map{|f| f["name"]}.should =~ %w[name rule]
      end
    end
  end

  context "/api/collections/tags/ID - get tag" do
    subject(:t) {Razor::Data::Tag.create(:name=>"tag_1", :rule => ["=",["fact","one"],"1"])}

    it "should return a JSON Siren tag" do
      get "/api/collections/tags/#{t.name}"
      last_response.status.should be 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("tag")]
    end

    it "should have the right keys" do
      get "/api/collections/tags/#{t.name}"

      tag = last_response.json
      tag["properties"].keys.should =~ %w[name rule]
      tag["properties"]["rule"].should == ["=",["fact","one"],"1"]
    end
  end

  context "/api/collections/images" do
    let!(:img1) {Fabricate(:image, :name => "image1")}
    let!(:img2) {Fabricate(:image, :name => "image2")}

    it "should return a JSON Siren list of images" do
      get "/api/collections/images"
      last_response.status.should be 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("collection"), class_url("image")]
    end

    it "should list all images" do

      get "/api/collections/images"
      last_response.status.should == 200
      img_list = last_response.json
      imgs = img_list["entities"]
      imgs.size.should == 2

      imgs.map { |img| img["properties"]["name"] }.should =~ %w[ image1 image2 ]
      imgs.all? do |img|
        img.keys.should =~ %w[properties href class rel]
        img["properties"].keys.should =~ ["name"]
      end
    end

    it "should have actions for images" do
      get '/api/collections/images'
      last_response.json["actions"].map{|a| a["name"]}.should =~ %w[create]
    end

    describe "'create' action" do
      subject(:create) do
        get '/api/collections/images'
        last_response.json["actions"].find {|act| act["name"]=="create" }
      end

      it do
        create["fields"].map{|f| f["name"]}.should =~ %w[name image-url]
      end
    end
  end

  context "/api/collections/images/:name" do
    let!(:img1) { Fabricate(:image, :name => "image1")}

    it "should return a JSON Siren image" do
      get "/api/collections/images/image1"
      last_response.status.should == 200
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("image")]
    end

    it "should find image by name" do
      get "/api/collections/images/image1"
      last_response.status.should == 200

      data = last_response.json
      data["properties"].keys.should =~ %w[name image_url]
      data["properties"]["name"].should == "image1"
    end

    it "should have actions" do
      get "/api/collections/images/image1"
      last_response.json["actions"].map {|a| a["name"]}.should =~ %w[delete]
    end

    describe "'delete' action" do
      subject(:delete) do
        get '/api/collections/images/image1'
        last_response.json["actions"].find {|act| act["name"]=="delete" }
      end

      it {delete["fields"].should be_empty}
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

    ROOT_KEYS = %w[name os description boot_seq]
    OS_KEYS = %w[name version]

    it "should return a JSON Siren installer" do
      get "/api/collections/installers/some_os"
      is_valid_siren?(last_response).should == true
      last_response.json["class"].should == [class_url("installer")]
    end

    it "works for file-based installers" do
      get "/api/collections/installers/some_os"
      last_response.status.should == 200
      data = last_response.json["properties"]

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

      data = last_response.json["properties"]
      data.keys.should =~ ROOT_KEYS
      data["name"].should == "dbinst"
      data["os"].keys.should =~ OS_KEYS
      data["boot_seq"].keys.should =~ %w[1 default]
    end
  end

  context "/api/collections/brokers" do
    BrokerItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Broker Collection JSON Schema",
      'type'     => 'object',
      'required' => %w[name configuration broker-type],
      'properties' => {
        'name'     => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^[a-zA-Z0-9 ]+$'
        },
        'broker-type' => {
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

      it "should return a JSON Siren empty set of brokers" do
        get "/api/collections/brokers"

        last_response.status.should == 200
        is_valid_siren?(last_response).should == true
        last_response.json["class"].should == [class_url("collection"), class_url("broker")]
        last_response.json["entities"].should be_an_instance_of Array
        last_response.json["entities"].count.should == expected
      end

      it "should have actions for tags" do
        get '/api/collections/brokers'
        last_response.json["actions"].map{|a| a["name"]}.should =~ %w[create]
      end

      describe "'create' action" do
        subject(:create) do
          get '/api/collections/brokers'
          last_response.json["actions"].find {|act| act["name"]=="create" }
        end

        it do
          create["fields"].map{|f| f["name"]}.should =~ %w[name configuration broker-type]
        end
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
            validate! BrokerItemSchema, last_response.json["properties"].to_json
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

  context "/api/collections/nodes" do

    NodeItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Node Collection JSON Schema",
      'type'     => 'object',
      'required' => %w[class properties entities],
      'properties' => {  # Properties of the root entity.
        'class'      => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'array',
          'items'      => {
            '$schema'    => 'http://json-schema.org/draft-04/schema#',
            'type'       => 'string',
            'pattern'    => '^https?://',
          },
        },
        'entities'   => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'array',
          'minItems'   => 1, # At least a log
          'maxItems'   => 2, # At most a policy and a log
          'items'      => {
            '$schema'    => 'http://json-schema.org/draft-04/schema#',
            'type'       => 'object',
            'required'   => %w[class href properties],
            'properties' => {
              'class' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'array',
                'items'    => {
                  '$schema'  => 'http://json-schema.org/draft-04/schema#',
                  'type'     => 'string',
                }
              },
              'href'       => {
                '$schema'    => 'http://json-schema.org/draft-04/schema#',
                'type'       => 'string',
                'pattern'    => '^https?://'
              },
              'rel'        => {
                '$schema'    => 'http://json-schema.org/draft-04/schema#',
                'type'       => 'array',
                'minItems'   => 1,
                'items'      => {
                  '$schema'    => 'http://json-schema.org/draft-04/schema#',
                  'type'       => 'string',
                  'pattern'    => '^https?://'
                },
              },
              'properties' => {  # 'properties' object of the policy entity
                '$schema'    => 'http://json-schema.org/draft-04/schema#',
                'type'       => 'object',
                'required'   => ["name"],
                'properties'   => {
                  'name'         => {
                    '$schema'     => 'http://json-schema.org/draft-04/schema#',
                    'type'        => 'string',
                    'minLength'   => 1,
                  },
                },
                'additionalProperties' => false,
              },
            },
            'additionalProperties' => false,
          },
        },
        'properties' => { # 'properties' object in the root entity
          'type'       => 'object',
          'properties'   => { # keys in the 'properties' object
            'name'     => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^[0-9a-fA-F]+$'
            },
            'hw_id'    => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^[0-9a-fA-F]+$'
            },
            'dhcp_mac' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^[0-9a-fA-F]+$'
            },
            'facts' => {
              '$schema'       => 'http://json-schema.org/draft-04/schema#',
              'type'          => 'object',
              'minProperties' => 1,
              'additionalProperties' => {
                '$schema'   => 'http://json-schema.org/draft-04/schema#',
                'type'      => 'string',
                'minLength' => 0
              }
            },
            'hostname' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
            },
            'root_password' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
            },
            'ip_address' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
            },
            'boot_count' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'integer',
              'minimum'  => 0
            },
          },
          'additionalProperties' => false,
        },
      },
      'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    shared_examples "a node collection" do |expected|
      before :each do
        Razor.config['broker_path'] =
          (Pathname(__FILE__).dirname.parent + 'fixtures' + 'brokers').realpath.to_s
      end

      it "should return a valid node response empty set" do
        get "/api/collections/nodes"

        last_response.status.should == 200
        is_valid_siren?(last_response).should == true
        last_response.json["entities"].count.should == expected
        last_response.json["class"].should == [class_url("collection"), class_url("node")]
      end
      it "should not return any actions" do
        get "/api/collections/nodes"
        last_response.json["actions"].should be_empty
      end


      it "should 404 a node requested that does not exist" do
        get "/api/collections/nodes/fast%20freddy"
        last_response.status.should == 404
      end

      if expected > 0
        it "should be able to access all node instances" do
          Razor::Data::Node.all.each do |node|
            get "/api/collections/nodes/#{URI.escape(node.name)}"
            last_response.status.should == 200
            is_valid_siren?(last_response).should == true
            validate! NodeItemSchema, last_response.body
            # Checking for the node and policy reference could be done in the schema,
            # but it's a lot easier to do it here

            policy = last_response.json["entities"].find {|ent| ent["class"]== [class_url("policy")]}

            unless node.policy.nil?
              policy["properties"].keys.should =~ ["name"]
            end

            log = last_response.json["entities"].find {|ent| ent["class"]== [class_url("node/log")]}
            log.should_not be_nil
            log["properties"]["name"].should_not be_empty
          end
        end
      end
    end

    context "with none" do
      it_should_behave_like "a node collection", 0
    end

    context "with one" do
      before :each do
        Fabricate(:bound_node)
      end

      it_should_behave_like "a node collection", 1
    end

    context "with ten" do
      before :each do
        5.times { Fabricate(:node) }
        5.times { Fabricate(:bound_node) }
      end

      it_should_behave_like "a node collection", 10
    end
  end
end
