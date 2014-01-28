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
      pl =  Fabricate(:policy, :repo => @repo, :task_name => "some_os")
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
      data.keys.should =~ %w[spec id name iso_url]
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
          'pattern'  => '^[a-zA-Z0-9_]+$'
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
              'pattern'  => '^[a-zA-Z0-9_]+$'
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
      get "/api/collections/tasks/some_os_derived"
      last_response.status.should == 200

      data = last_response.json
      data["name"].should == "some_os_derived"
      data["os"]["version"].should == "4"
      data["base"]["name"].should == "some_os"
      validate! TaskItemSchema, last_response.body
    end
  end

  context "/api/collections/brokers" do
    BrokerItemSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Broker Collection JSON Schema",
      'type'     => 'object',
      'required' => %w[spec id name configuration broker-type],
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
  end
end
