# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

require 'json-schema'

describe "command and query API" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    authorize 'fred', 'dead'
  end

  # JSON schema for collections where we only send back object references;
  # these are the same no matter what the underlying collection elements
  # look like
  ObjectRefCollectionSchema = {
    '$schema'  => 'http://json-schema.org/draft-04/schema#',
    'title'    => "Broker Collection JSON Schema",
    'type'     => 'object',
    'additionalProperties' => false,
    'properties' => {
      "spec" => {
        '$schema' => 'http://json-schema.org/draft-04/schema#',
        'type'    => 'string',
        'pattern' => '^https?://'
      },
      "items" => {
        '$schema' => 'http://json-schema.org/draft-04/schema#',
        'type'    => 'array',
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
            "name" => {
              '$schema' => 'http://json-schema.org/draft-04/schema#',
              'type'    => 'string',
              'pattern' => '^[^\n]+$'
            }
          }
        }
      },
      'total' => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'number'
      }
    }
  }.freeze

  context "/ - API navigation index" do
    %w[text/plain text/html text/* application/js].each do |type|
      it "should reject #{type.inspect} content requests" do
        header 'Accept', type
        get '/api'
        last_response.status.should == 406
      end
    end

    it "should properly set the hostname in links" do
      # This tests https://tickets.puppetlabs.com/browse/RAZOR-93
      # The first request to /api would 'bake' the hostname into
      # command URL's
      header 'Host', 'example.net'
      get '/api'

      header 'Host', 'example.com'
      get '/api'

      api = last_response.json
      (api['commands'] + api['collections']).each do |x|
        uri = URI::parse(x['id'])
        uri.host.should be == 'example.com',
          "id for #{x['name']} is '#{uri.host}' but should be 'example.com'"
      end
    end

    it "should return JSON content" do
      get '/api'
      last_response.content_type.should =~ /application\/json/i
    end

    it "should match the shape of our command handler" do
      get '/api'
      data = last_response.json
      data.keys.should =~ %w[commands collections version]
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

    describe "securing /api" do
      it "should allow secure when secure_api is true" do
        Razor.config['secure_api'] = true
        get "/api", {}, 'HTTPS' => 'on'
        last_response.status.should == 200
      end
      it "should allow secure when secure_api is false" do
        Razor.config['secure_api'] = false
        get "/api", {}, 'HTTPS' => 'on'
        last_response.status.should == 200
      end
      it "should disallow insecure when secure_api is true" do
        Razor.config['secure_api'] = true
        get "/api", {}, 'HTTPS' => 'off'
        last_response.status.should == 404
        last_response.json['error'].should == 'API requests must be over SSL (secure_api config property is enabled)'
      end
      it "should allow insecure when secure_api is false" do
        Razor.config['secure_api'] = false
        get "/api", {}, 'HTTPS' => 'off'
        last_response.status.should == 200
      end
    end
  end

  context "/api/collections/policies - policy list" do

    # `before` is used instead of `let` since the database gets rolled
    # back after every test
    before(:each) do
      use_task_fixtures

      @node = Fabricate(:node_with_facts)
      @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
      @repo = Fabricate(:repo)
    end

    it "should return JSON content" do
      get '/api/collections/policies'
      last_response.status.should == 200
      last_response.content_type.should =~ /application\/json/i
    end

    it "should list all policies" do
      pl =  Fabricate(:policy, :repo => @repo)
      pl.add_tag @tag

      get '/api/collections/policies'
      data = last_response.json['items']
      data.size.should be 1
      data.all? do |policy|
        policy.keys.should =~ %w[id name spec]
      end
    end
  end

  context "/api/collections/policies/ID - get policy" do
    before(:each) do
      use_task_fixtures

      @node = Fabricate(:node_with_facts)
      @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
      @repo = Fabricate(:repo)
    end

    subject(:pl){ Fabricate(:policy, :repo => @repo, :task_name => "some_os")}

    it "should exist" do
      get "/api/collections/policies/#{URI.escape(pl.name)}"
      last_response.status.should be 200
    end

    it "should have the right keys" do
      pl.max_count = 10
      pl.node_metadata = { "key1" => "val1" }
      pl.save

      get "/api/collections/policies/#{URI.escape(pl.name)}"
      policy = last_response.json

      policy.keys.should =~ %w[name id spec configuration enabled max_count repo tags task broker node_metadata nodes]
      policy["repo"].keys.should =~ %w[id name spec]
      policy["configuration"].keys.should =~ %w[hostname_pattern root_password]
      policy["tags"].should be_empty
      policy["tags"].all? {|tag| tag.keys.should =~ %w[spec url obj_id name] }
      policy["broker"].keys.should =~ %w[id name spec]
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
      data = last_response.json['items']
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
      tag.keys.should =~ %w[ spec id name rule nodes policies]
      tag["rule"].should == ["=",["fact","one"],"1"]
    end
  end

  context "/api/collections/repos" do
    it "should list all repos" do
      repo1 = Fabricate(:repo, :name => "repo1")
      repo2 = Fabricate(:repo, :name => "repo2")

      get "/api/collections/repos"
      last_response.status.should == 200

      repos = last_response.json['items']
      repos.size.should == 2
      repos.map { |repo| repo["name"] }.should =~ %w[ repo1 repo2 ]
      repos.all? { |repo| repo.keys.should =~ %w[id name spec] }
    end
  end

  context "/api/collections/repos/:name" do
    it "should find repo by name" do
      repo1 = Fabricate(:repo, :name => "repo1")

      get "/api/collections/repos/#{repo1.name}"
      last_response.status.should == 200

      data = last_response.json
      data.keys.should =~ %w[spec id name iso_url task url]
    end

    it "should return 404 when repo not found" do
      get "/api/collections/repos/not_an_repo"
      last_response.status.should == 404
    end
  end

  context "/api/collections/tasks/:name" do
    # @todo lutter 2013-10-08: I would like to pull the schema for the base
    # property out into a ObjectReferenceSchema and make the base property
    # a $ref to that. My attempts at doing that have failed so far, because
    # json-schema fails when we validate against the resulting
    # TaskItemSchema, complaining that the schema for base is not
    # valid
    #
    # Note that to use a separate ObjectReferenceSchema, we have to
    # register it first with the Validator:
    #   url = "http://api.puppetlabs.com/razor/v1/reference"
    #   ObjectReferenceSchema['id'] = url
    #   sch = JSON::Schema::new(ObjectReferenceSchema, url)
    #   JSON::Validator.add_schema(sch)
    TaskItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Task Item JSON Schema",
      'type'     => 'object',
      'required' => %w[spec id name os boot_seq],
      'properties' => {
        'spec' => {
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'id'       => {
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'name'     => {
          'type'     => 'string',
          'pattern'  => '^[a-zA-Z0-9_/]+$'
        },
        'base'     => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Object Reference Schema",
          'type'     => 'object',
          'required' => %w[spec id name],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9_/]+$'
            }
          },
          'additionalProperties' => false
        },
        'description' => {
          'type'     => 'string'
        },
        'os' => {
          'type'    => 'object',
          'properties' => {
            'name' => {
              'type' => 'string'
            },
            'version' => {
              'type' => 'string'
            }
          }
        },
        'boot_seq' => {
          'type' => 'object',
          'required' => %w[default],
          'patternProperties' => {
            "^([0-9]+|default)$" => {}
          },
          'additionalProperties' => false,
        }
      },
      'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    before(:each) do
      use_task_fixtures
    end

    it "works for file-based tasks" do
      get "/api/collections/tasks/some_os"
      last_response.status.should == 200

      data = last_response.json
      data["name"].should == "some_os"
      data["boot_seq"].keys.should =~ %w[1 2 default]
      data["boot_seq"]["2"].should == "boot_again"
      validate! TaskItemSchema, last_response.body
    end

    it "works for DB-backed tasks" do
      inst = Razor::Data::Task.create(:name => 'dbinst',
                                           :os => 'SomeOS',
                                           :os_version => '6',
                                           :boot_seq => { 1 => "task",
                                                          "default" => "local"})
      get "/api/collections/tasks/dbinst"
      last_response.status.should == 200

      data = last_response.json
      data["name"].should == "dbinst"
      data["boot_seq"].keys.should =~ %w[1 default]
      validate! TaskItemSchema, last_response.body
    end

    it "includes a reference to the base task" do
      get "/api/collections/tasks/some_os/derived"
      last_response.status.should == 200

      data = last_response.json
      data["name"].should == "some_os/derived"
      data["os"]["version"].should == "4"
      data["base"]["name"].should == "some_os/base"
      validate! TaskItemSchema, last_response.body
    end
  end

  context "/api/collections/brokers" do
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
        },
        'policies'     => {
          '$schema' => 'http://json-schema.org/draft-04/schema#',
          'type'    => 'object',
          'required' => %w[id count name],
          'properties' => {
            'id'   => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'count'     => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'integer'
            },
            'name'     => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9 ]+$'
            }
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

        brokers = last_response.json['items']
        brokers.should be_an_instance_of Array
        brokers.count.should == expected
        validate! ObjectRefCollectionSchema, last_response.body
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

  context "/api/collections/nodes" do
    NodeItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Node Collection JSON Schema",
      'type'     => 'object',
      'required' => %w[spec id name],
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
          'pattern'  => '^node[0-9]+$'
        },
        'hw_info'    => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'object'
        },
        'dhcp_mac' => {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'type'     => 'string',
          'pattern'  => '^[0-9a-fA-F]+$'
        },
        'log'   => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'object',
          'required'   => %w[id name],
          'properties' => {
            'id'       => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              '$schema'   => 'http://json-schema.org/draft-04/schema#',
              'type'      => 'string',
              'minLength' => 1
            },
          },
        },
        'tags'     => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'array',
          'items'      => {
            'type'       => 'object',
            'required'   => %w[id name spec],
            'properties'  => {
              'id'       => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'string',
                'pattern'  => '^https?://'
              },
              'name'     => {
                '$schema'   => 'http://json-schema.org/draft-04/schema#',
                'type'      => 'string',
                'minLength' => 1
              },
              'spec' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'string',
                'pattern'  => '^https?://'
              },
            },
          },
        },
        'policy'   => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'object',
          'required'   => %w[spec id name],
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
              '$schema'   => 'http://json-schema.org/draft-04/schema#',
              'type'      => 'string',
              'minLength' => 1
            },
          },
          'additionalProperties' => false,
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
        'metadata' => {
          '$schema'       => 'http://json-schema.org/draft-04/schema#',
          'type'          => 'object',
          'minProperties' => 0,
          'additionalProperties' => {
            '$schema'   => 'http://json-schema.org/draft-04/schema#',
            'type'      => 'string',
            'minLength' => 0
          }
        },
        'state' => {
          '$schema'       => 'http://json-schema.org/draft-04/schema#',
          'type'          => 'object',
          'minProperties' => 0,
          'properties'    => {
            'installed' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => ['string', 'boolean'],
            }
          },
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
        'power' => {
          '$schema'    => 'http://json-schema.org/draft-04/schema#',
          'type'       => 'object',
          'properties' => {
            'desired_power_state' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => ['string', 'null'],
              'pattern'  => 'on|off'
            },
            'last_known_power_state' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => ['string', 'null'],
              'pattern'  => 'on|off'
            },
            'last_power_state_update_at' => {
              '$schema'  => 'http://json-schema.org/draft-04/schema#',
              'type'     => ['string', 'null'],
              # 'pattern' => '' ...date field.
            }
          },
          'additionalProperties' => false,
        },
        'ipmi' => {
            'hostname' => nil,
            'username' => nil
        }
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
        nodes = last_response.json['items']
        nodes.should be_an_instance_of Array
        nodes.count.should == expected
        validate! ObjectRefCollectionSchema, last_response.body
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
            validate! NodeItemSchema, last_response.body
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

    it "should state that 'start' and 'limit' are valid parameters" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'nodes'}.first['params']
      params.should == {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}
    end

    context "limiting" do
      let :names do [] end
      before :each do
        5.times { names.push(Fabricate(:node).name) }
        # Verify that the array of names matches what's on the server.
        get "/api/collections/nodes"
        last_response.json['error'].should be_nil
        last_response.status.should == 200
        last_response.json['items'].map {|e| e['name']}.should == names
      end
      it "should show limited nodes" do
        get "/api/collections/nodes?limit=2"
        last_response.status.should == 200

        last_response.json['items'].map {|e| e['name']}.should == names[0..1]
      end
      it "should show limited nodes with offset" do
        get "/api/collections/nodes?limit=2&start=2"
        last_response.status.should == 200

        last_response.json['items'].map {|e| e['name']}.should == names[2..3]
      end
    end
  end

  context "/api/collections/nodes/:name" do
    let :node do Fabricate(:node) end

    it "should include installed if installed" do
      node.set(installed: 'nothing').save
      get "/api/collections/nodes/#{node.name}"
      last_response.status.should == 200

      last_response.json.should have_key 'state'
      last_response.json['state'].should include 'installed' => 'nothing'
    end

    it "should default to installed false" do
      get "/api/collections/nodes/#{node.name}"
      last_response.status.should == 200

      last_response.json.should have_key 'state'
      last_response.json['state'].should include 'installed' => false
    end

    it "should include installed false if not installed" do
      node.set(installed: nil).save
      get "/api/collections/nodes/#{node.name}"
      last_response.status.should == 200

      last_response.json.should have_key 'state'
      last_response.json['state'].should include 'installed' => false
    end

    it "should include node log params" do
      get "/api/collections/nodes/#{node.name}"
      last_response.status.should == 200

      last_response.json.should have_key 'log'
      last_response.json['log'].should include 'params' => {'limit' => {'type' => 'number'}, 'start' => {'type' => 'number'}}
    end
  end

  context "/api/collections/nodes/:name/log" do
    let :node do Fabricate(:node) end
    let :msgs do [] end
    before :each do
      5.times { msgs.unshift(Fabricate(:event, node: node).entry[:msg]) }
    end
    it "should show log" do
      get "/api/collections/nodes/#{node.name}/log"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs
    end
    it "should show limited log" do
      get "/api/collections/nodes/#{node.name}/log?limit=2"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs[0..1]
    end
    it "should show limited log with offset" do
      get "/api/collections/nodes/#{node.name}/log?limit=2&start=2"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs[2..3]
    end
  end

  context "/api/collections/commands" do
    CommandItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Command item JSON Schema",
      'type'     => 'object',
      'required' => %w[spec id name command],
      'properties' => {
        'spec' => {
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'id'       => {
          'type'     => 'string',
          'pattern'  => '^https?://'
        },
        'name'     => {
          'type'     => 'string',
          'pattern'  => '^[0-9]+$'
        },
        'command'    => {
          'type'     => 'string',
          'pattern'  => '^[a-z-]+$'
        },
        'params'     => {
          'type'     => 'object',
        },
        'errors'     => {
          'type'     => 'array',
          'items'    =>  {
            'type'     => 'object',
            'required' => %w[exception message attempted_at],
            'properties' => {
              'exception' => {
                 'type'   => 'string'
              },
              'message'   => {
                'type'    => 'string'
              },
              'attempted_at' => {
                'type' => 'string'
              }
            },
            'additionalProperties' => false
          }
        },
        'status' => {
          'type'     => 'string',
          'pattern'  => '^(pending|running|finished|failed)$'
        },
        'submitted_at' => {
          'type'       => 'string',
        },
        'finished_at'  => {
          'type'       => 'string'
        }
      },
      'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    shared_examples "a command collection" do |expected|
      it "should return a valid collection" do
        get "/api/collections/commands"

        last_response.status.should == 200
        nodes = last_response.json['items']
        nodes.should be_an_instance_of Array
        nodes.count.should == expected
        validate! ObjectRefCollectionSchema, last_response.body
      end

      it "should 404 a command requested that does not exist" do
        get "/api/collections/commands/fast%20freddy"
        last_response.status.should == 404
      end

      if expected > 0
        it "should be able to access all command instances" do
          Razor::Data::Command.all.each do |command|
            get "/api/collections/commands/#{command.name}"
            last_response.status.should == 200
            validate! CommandItemSchema, last_response.body
          end
        end
      end
    end

    context "with none" do
      it_should_behave_like "a command collection", 0
    end

    context "with one" do
      before :each do
        Fabricate(:command)
      end

      it_should_behave_like "a command collection", 1
    end

    context "with ten" do
      before :each do
        10.times { Fabricate(:command) }
      end

      it_should_behave_like "a command collection", 10
    end

    it "should report errors in an array" do
      command = Fabricate(:command)
      command.add_exception Exception.new("Exception 1")
      command.add_exception Exception.new("Exception 2")
      command.store('failed')
      get "/api/collections/commands/#{command.id}"
      last_response.status.should == 200
      validate! CommandItemSchema, last_response.body

      last_response.json['status'].should == 'failed'
      last_response.json['errors'].should_not be_nil
      last_response.json['errors'][0]['message'].should == "Exception 1"
      last_response.json['errors'][1]['message'].should == "Exception 2"
    end
  end

  context "/api/collections/hooks" do
    before :each do
      Razor.config['hook_path'] =
          (Pathname(__FILE__).dirname.parent + 'fixtures' + 'hooks').realpath.to_s
    end

    HookItemSchema = {
        '$schema'  => 'http://json-schema.org/draft-04/schema#',
        'title'    => "Hook Collection JSON Schema",
        'type'     => 'object',
        'required' => %w[spec id name hook_type],
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
                'pattern'  => '^[^\n]+$'
            },
            'hook_type' => {
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
            },
            'log'   => {
                '$schema'    => 'http://json-schema.org/draft-04/schema#',
                'type'       => 'object',
                'required'   => %w[id name],
                'properties' => {
                    'id'       => {
                        '$schema'  => 'http://json-schema.org/draft-04/schema#',
                        'type'     => 'string',
                        'pattern'  => '^https?://'
                    },
                    'name'     => {
                        '$schema'   => 'http://json-schema.org/draft-04/schema#',
                        'type'      => 'string',
                        'minLength' => 1
                    },
                },
            },
        },
        'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    shared_examples "a hook collection" do |expected|
      it "should return a valid collection" do
        get "/api/collections/hooks"

        last_response.status.should == 200
        nodes = last_response.json['items']
        nodes.should be_an_instance_of Array
        nodes.count.should == expected
        validate! ObjectRefCollectionSchema, last_response.body
      end

      it "should 404 a hook requested that does not exist" do
        get "/api/collections/hooks/fast%20freddy"
        last_response.status.should == 404
      end

      if expected > 0
        it "should be able to access all hook instances" do
          Razor::Data::Hook.all.each do |hook|
            get "/api/collections/hooks/#{URI::escape(hook.name)}"
            last_response.status.should == 200
            validate! HookItemSchema, last_response.body
          end
        end
      end
    end

    context "with none" do
      it_should_behave_like "a hook collection", 0
    end

    context "with one" do
      before :each do
        Fabricate(:hook)
      end

      it_should_behave_like "a hook collection", 1
    end

    context "with ten" do
      before :each do
        10.times { Fabricate(:hook) }
      end

      it_should_behave_like "a hook collection", 10
    end
  end

  context "/api/collections/hooks/:name" do
    let :hook do Fabricate(:hook) end

    it "should include hook log params" do
      get "/api/collections/hooks/#{URI.escape(hook.name)}"
      last_response.status.should == 200

      last_response.json.should have_key 'log'
      last_response.json['log'].should include 'params' => {'limit' => {'type' => 'number'}, 'start' => {'type' => 'number'}}
    end
  end

  context "/api/collections/hooks/:name/log" do
    let :hook do Fabricate(:hook) end
    let :msgs do [] end
    before :each do
      5.times { msgs.unshift(Fabricate(:event, hook: hook).entry[:msg]) }
    end
    it "should show log" do
      get "/api/collections/hooks/#{URI.escape(hook.name)}/log"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs
    end
    it "should show limited log" do
      get "/api/collections/hooks/#{URI.escape(hook.name)}/log?limit=2"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs[0..1]
    end
    it "should show limited log with offset" do
      get "/api/collections/hooks/#{URI.escape(hook.name)}/log?limit=2&start=2"
      last_response.status.should == 200

      last_response.json['items'].map {|e| e['msg']}.should == msgs[2..3]
    end
  end

  context "/api/microkernel/bootstrap" do
    it "generates a script for 4 NIC's if nic_max is not given" do
      get "/api/microkernel/bootstrap"
      last_response.status.should == 200
      4.times.each do |i|
        last_response.body.should =~ /^[^#]*dhcp\s+net#{i}/m
      end
    end

    it "accepts a nic_max parameter" do
      get "/api/microkernel/bootstrap?nic_max=7"
      last_response.status.should == 200
      7.times.each do |i|
        last_response.body.should =~ /^[^#]*dhcp\s+net#{i}/m
      end
    end

    it "accepts a http_port parameter" do
      get "/api/microkernel/bootstrap?http_port=8150"
      last_response.status.should == 200
      last_response.body.should =~ /:8150/
    end
  end

  context "/api/collections/events" do
    EventItemSchema = {
        '$schema'  => 'http://json-schema.org/draft-04/schema#',
        'title'    => "Event Collection JSON Schema",
        'type'     => 'object',
        'required' => %w[spec id name severity entry],
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
                'type'     => 'number',
                'pattern'  => '^[^\n]+$'
            },
            'node' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'object'
            },
            'policy' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'object'
            },
            'timestamp' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'string'
                # 'pattern' => '' ...date field.
            },
            'entry' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'object'
            },
            'severity' => {
                '$schema'  => 'http://json-schema.org/draft-04/schema#',
                'type'     => 'string',
                'pattern'   => 'error|warning|info',
            }
        },
        'additionalProperties' => false,
    }.freeze

    def validate!(schema, json)
      # Why does the validate method insist it should be able to modify
      # my schema?  That would be, y'know, bad.
      JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
    end

    it "should 404 a event requested that does not exist" do
      get "/api/collections/events/238902423"
      last_response.status.should == 404
    end

    it "should error on bad-format for event" do
      get "/api/collections/events/foo"
      last_response.status.should == 400
      last_response.json['error'].should =~ /id must be a number but was foo/
    end

    shared_examples "a event collection" do |expected|
      it "should return a valid collection" do
        get "/api/collections/events"

        last_response.status.should == 200
        nodes = last_response.json['items']
        nodes.should be_an_instance_of Array
        nodes.count.should == expected
        validate! ObjectRefCollectionSchema, last_response.body
      end

      if expected > 0
        it "should be able to access all event instances" do
          Razor::Data::Event.all.each do |event|
            get "/api/collections/events/#{URI::escape(event.name)}"
            last_response.status.should == 200
            validate! EventItemSchema, last_response.body
          end
        end
      end
    end

    context "with none" do
      it_should_behave_like "a event collection", 0
    end

    context "with one" do
      before :each do
        Fabricate(:event)
      end

      it_should_behave_like "a event collection", 1
    end

    context "with ten" do
      before :each do
        10.times { Fabricate(:event) }
      end

      it_should_behave_like "a event collection", 10
    end

    context "event limiting" do
      it "should state that 'start' and 'limit' are valid parameters" do
        get '/api'
        params = last_response.json['collections'].select {|c| c['name'] == 'events'}.first['params']
        params.should == {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}
      end
      it "should view all results by default" do
        21.times { Fabricate(:event) }
        get "/api/collections/events"

        last_response.status.should == 200
        events = last_response.json['items']
        events.should be_an_instance_of Array
        events.count.should == 21
        last_response.json['total'].should == 21
        validate! ObjectRefCollectionSchema, last_response.body
      end
      it "should allow limiting results" do
        names = []
        3.times { names << Fabricate(:event).name }
        get "/api/collections/events?limit=1"

        last_response.status.should == 200
        events = last_response.json['items']
        events.should be_an_instance_of Array
        events.count.should == 1
        events.first['name'].should == names.last
        last_response.json['total'].should == 3
        validate! ObjectRefCollectionSchema, last_response.body
      end
      it "should allow windowing of results" do
        names = []
        6.times { names.unshift Fabricate(:event).name }
        get "/api/collections/events?limit=2&start=2"

        last_response.status.should == 200
        events = last_response.json['items']
        events.should be_an_instance_of Array
        events.map {|n| n['name']}.should == names[2..3]
        events.count.should == 2
        last_response.json['total'].should == 6
        validate! ObjectRefCollectionSchema, last_response.body
      end
      it "should allow just an offset" do
        names = []
        6.times { names.unshift Fabricate(:event).name }
        get "/api/collections/events?start=2"

        last_response.status.should == 200
        events = last_response.json['items']
        events.should be_an_instance_of Array
        events.map {|n| n['name']}.should == names[2..-1]
        events.count.should == 4
        last_response.json['total'].should == 6
        validate! ObjectRefCollectionSchema, last_response.body
      end
    end
  end
end
