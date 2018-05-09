# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

require 'json-schema'

describe "command and query API", :api_spec => true do
  # extend lets us use the helpers outside of an "it" block,
  # include lets us use them inside of the "it" block.
  include Rack::Test::Methods
  extend Razor::Spec::CollectionSchemas
  include Razor::Spec::CollectionSchemas

  let(:app) { Razor::App }
  let(:depth_param) { { 'depth' => { "type" => "number" } } }

  before :each do
    authorize 'fred', 'dead'
  end

  # Returns a generation function that uses fabricate
  # to generate 'size' amount of items. It is meant to be
  # used with the "depth parameter tests" shared example
  # below.
  def coll_generator_from_fabricate(size, item)
    lambda do
      size.times { Fabricate(item) }
      size
    end
  end

  # This shared example gives the caller two options. Either they:
  #   (1) Can initialize their own collection, whereby they are required to set the
  #   @expected_coll_size instance variable indicating the collection size
  #
  #   (2) Can pass-in a function that generates the collection, declared as "generate_coll".
  #   "generate_coll" should return the size of the generated collection. Note that
  #   "generate_coll" must be initialized in a previous context, or you can initialize
  #   it with:
  #     include_examples "depth parameter tests" <endpoint>, <item_schema> do
  #       let(:generate_coll) do
  #         <code goes here, should return a callable object (e.g. a lambda)>
  #       end
  #     end
  shared_examples "depth parameter tests" do |endpoint, item_schema|
    context "with the depth parameter" do
      let(:collection_endpoint) { "/api/collections/#{endpoint}" }
      before(:each) do
        next if @expected_coll_size
        unless defined?(generate_coll) && generate_coll.respond_to?(:call)
          fail "The items for #{collection_endpoint} have not been created,"\
               " and a generation function 'generate_coll' is not provided!"
        end

        @expected_coll_size = generate_coll.call()
      end

      context "depth == 0" do
        it "should return a list of item references" do
          get "#{collection_endpoint}?depth=0"
          last_response.status.should == 200
  
          items = last_response.json['items']
          items.should be_an_instance_of Array
          items.count.should == @expected_coll_size
          validate_schema! collection_schema, last_response.body
        end
      end
  
      context "depth == 1" do
        it "should return a detailed list of the items in the collection" do
          get "#{collection_endpoint}?depth=1"
          last_response.status.should == 200
  
          items = last_response.json['items']
          items.should be_an_instance_of Array
          items.count.should == @expected_coll_size
          validate_schema! collection_schema(item_schema), last_response.body
        end
      end
  
      context "invalid depth" do
        it "should return a 400 error response" do
          get "#{collection_endpoint}?depth=bad_depth"
          last_response.status.should == 400
        end
      end
    end
  end

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

  context "/api/commands/*" do
    CommandSchema = {
      '$schema'  => 'http://json-schema.org/draft-04/schema#',
      'title'    => "Command JSON Schema",
      'type'     => 'object',
      'additionalProperties' => false,
      'required' => %w[name help schema],
      'properties' => {
        "name" => {
          'type'    => 'string',
          'pattern' => '^[^\n]+$'
        },
        "help" => {
          'type'    => 'object',
          'additionalProperties' => false,
          'required' => %w[summary description schema examples full],
          'properties' => {
            'summary' => {
              'type'    => 'string',
              'pattern' => '^[^\n]+$'
            },
            'description' => {
              'type'    => 'string'
            },
            'schema' => {
              'type'    => 'string'
            },
            'examples' => {
              'type'    => 'object',
              'additionalProperties' => false,
              'required' => %w[api cli],
              'properties' => {
                  'api' => {
                      'type' => 'string'
                  },
                  'cli' => {
                      'type' => 'string'
                  }
              }
            },
            'full' => {
              'type'    => 'string'
            }
          }
        },
        "schema" => {
          'type'    => 'object',
          'additionalProperties' => {
            'type' => 'object',
            'minLength' => 1,
            'additionalProperties' => false,
            'properties' => {
              'type' => {
                'type' => 'string',
                'pattern' => '^[^\n]+$'
              },
              'aliases' => {
                'type' => 'array'
              },
              'position' => {
                'type' => 'integer',
                'minimum' => 0
              }
            }
          }
        }
      }
    }.freeze

    it "should include the correct command schema" do
      get '/api'
      data = last_response.json
      data["commands"].all? do |row|
        get row['id']
        validate_schema! CommandSchema, last_response.body
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

      @mock_policies = [
        Fabricate(:policy, :repo => @repo).tap do |pl| 
          pl.add_tag @tag
          pl.max_count = 10
          pl.node_metadata = { "key1" => "val1" }

          pl.save
        end
      ]
      @expected_coll_size = @mock_policies.size
    end

    it "should return JSON content" do
      get '/api/collections/policies'
      last_response.status.should == 200
      last_response.content_type.should =~ /application\/json/i
    end

    it "should list all policies" do
      get '/api/collections/policies'

      policies = last_response.json['items']
      policies.size.should be @expected_coll_size
      validate_schema! collection_schema, last_response.body
    end

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'policies'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "policies", policy_item_schema
  end

  context "/api/collections/policies/ID - get policy" do
    before(:each) do
      use_task_fixtures

      @node = Fabricate(:node_with_facts)
      @tag = Razor::Data::Tag.create(:name => "t1", :rule => ["=", ["fact", "f1"], "a"])
      @repo = Fabricate(:repo)

      @mock_policy = Fabricate(:policy, :repo => @repo).tap do |pl| 
        pl.add_tag @tag
        pl.max_count = 10
        pl.node_metadata = { "key1" => "val1" }

        pl.save
      end
    end

    it "should have the right keys" do
      get "/api/collections/policies/#{URI.escape(@mock_policy.name)}"
      last_response.status.should be 200
      validate_schema! policy_item_schema, last_response.body
    end
  end

  context "/api/collections/tags - tag list" do
    before(:each) do
      @mock_tags = [
        Razor::Data::Tag.create(:name=>"tag_1", :matcher =>Razor::Matcher.new(["=",["fact","one"],"1"]))
      ]
      @expected_coll_size = @mock_tags.size
    end

    it "should return JSON content" do
      get '/api/collections/tags'
      last_response.status.should == 200
      last_response.content_type.should =~ /application\/json/
    end

    it "should list all tags" do
      get '/api/collections/tags'
      last_response.status.should == 200

      tags = last_response.json['items']
      tags.size.should == @expected_coll_size
      validate_schema! collection_schema, last_response.body
    end

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'tags'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "/tags", tag_item_schema
  end

  context "/api/collections/tags/ID - get tag" do
    it "should exist and have the right keys" do
      t = Razor::Data::Tag.create(:name=>"tag_1", :matcher =>Razor::Matcher.new(["=",["fact","one"],"1"]))
      get "/api/collections/tags/#{t.name}"
      last_response.status.should be 200

      tag = last_response.json
      validate_schema! tag_item_schema, last_response.body
      tag["rule"].should == ["=",["fact","one"],"1"]
    end
  end

  context "/api/collections/repos" do
    before(:each) do
      @mock_repos = (0..2).map { |i| Fabricate(:repo, :name => "repo#{i}") }
      @expected_coll_size = @mock_repos.size
    end

    it "should list all repos" do
      get "/api/collections/repos"
      last_response.status.should == 200

      repos = last_response.json['items']
      repos.size.should == @expected_coll_size
      validate_schema! collection_schema, last_response.body
    end

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'repos'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "repos", repo_item_schema
  end

  context "/api/collections/repos/:name" do
    it "should find repo by name" do
      repo1 = Fabricate(:repo, :name => "repo1")

      get "/api/collections/repos/#{repo1.name}"
      last_response.status.should == 200
      validate_schema! repo_item_schema, last_response.body 
    end

    it "should return 404 when repo not found" do
      get "/api/collections/repos/not_a_repo"
      last_response.status.should == 404
    end
  end

  context "/api/collections/tasks" do
    before(:each) do
      use_task_fixtures
      @expected_coll_size = Razor::Task.all.size
    end

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'tasks'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "tasks", task_item_schema
  end

  context "/api/collections/tasks/:name" do
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
      validate_schema! task_item_schema, last_response.body
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
      validate_schema! task_item_schema, last_response.body
    end

    it "includes a reference to the base task" do
      get "/api/collections/tasks/some_os/derived"
      last_response.status.should == 200

      data = last_response.json
      data["name"].should == "some_os/derived"
      data["os"]["version"].should == "4"
      data["base"]["name"].should == "some_os/base"
      validate_schema! task_item_schema, last_response.body
    end
  end

  context "/api/collections/brokers" do
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
        validate_schema! collection_schema, last_response.body
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
            validate_schema! broker_item_schema, last_response.body
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

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'brokers'}.first['params']
      params.should == depth_param 
    end

    include_examples "depth parameter tests", "brokers", broker_item_schema do
      let(:generate_coll) do
        lambda do
          Razor.config['broker_path'] =
          (Pathname(__FILE__).dirname.parent + 'fixtures' + 'brokers').realpath.to_s
    
          coll_generator_from_fabricate(10, :broker).call() 
        end
      end
    end
  end

  context "/api/collections/nodes" do
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
        validate_schema! collection_schema, last_response.body
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
            validate_schema! node_item_schema, last_response.body
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

    it "should state that 'start', 'limit' and 'depth' are valid parameters" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'nodes'}.first['params']
      params.should == {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}.merge(depth_param)
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

    include_examples "depth parameter tests", "nodes", node_item_schema do
      let(:generate_coll)  { coll_generator_from_fabricate(10, :node) }
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
  context "/api/collections/config" do
    ConfigCollectionSchema = {
        '$schema'  => 'http://json-schema.org/draft-04/schema#',
        'title'    => "Config Collection JSON Schema",
        'type'     => 'object',
        'additionalProperties' => false,
        'properties' => {
            "spec" => {
                'type'    => 'string',
                'pattern' => '^https?://'
            },
            "items" => {
                'type'    => 'array',
                'items'    => {
                    'type'     => 'object',
                    'additionalProperties' => true,
                }
            }
        }
    }.freeze

    it "should return the config" do
      Razor.config['api_config_blacklist'] = ['database_url', 'facts.blacklist']
      get '/api/collections/config'
      last_response.status.should == 200
      validate_schema! ConfigCollectionSchema, last_response.body

      items = last_response.json['items']
      count = Razor.config.flat_values.length - Razor.config['api_config_blacklist'].length
      items.length.should == count

      items.each do |item|
        Razor.config[item['name']].should == item['value']
      end

      Razor.config['api_config_blacklist'].each do |k,_|
        items.map { |item| item['name'] }.should_not include k
      end
    end

    it "should succeed without a config set" do
      Razor.config['api_config_blacklist'] = nil
      get '/api/collections/config'
      last_response.status.should == 200

      items = last_response.json['items']
      items.length.should == Razor.config.flat_values.length
      items.length.should > 0 # Just in case
    end
  end

  context "/api/collections/commands" do
    shared_examples "a command collection" do |expected|
      it "should return a valid collection" do
        get "/api/collections/commands"

        last_response.status.should == 200
        nodes = last_response.json['items']
        nodes.should be_an_instance_of Array
        nodes.count.should == expected
        validate_schema! collection_schema, last_response.body
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
            validate_schema! command_item_schema, last_response.body
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
      validate_schema! command_item_schema, last_response.body

      last_response.json['status'].should == 'failed'
      last_response.json['errors'].should_not be_nil
      last_response.json['errors'][0]['message'].should == "Exception 1"
      last_response.json['errors'][1]['message'].should == "Exception 2"
    end

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'commands'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "commands", command_item_schema do
      let(:generate_coll) { coll_generator_from_fabricate(10, :command) }
    end
  end

  context "/api/collections/hooks" do
    before :each do
      use_hook_fixtures
    end

    shared_examples "a hook collection" do |expected|
      it "should return a valid collection" do
        get "/api/collections/hooks"

        last_response.status.should == 200
        hooks = last_response.json['items']
        hooks.should be_an_instance_of Array
        hooks.count.should == expected
        validate_schema! collection_schema, last_response.body
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
            validate_schema! hook_item_schema, last_response.body
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

    it "should state that 'depth' is a valid parameter" do
      get '/api'
      params = last_response.json['collections'].select {|c| c['name'] == 'hooks'}.first['params']
      params.should == depth_param
    end

    include_examples "depth parameter tests", "hooks", hook_item_schema do
      let(:generate_coll) { coll_generator_from_fabricate(10, :hook) }
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
        validate_schema! collection_schema, last_response.body
      end

      if expected > 0
        it "should be able to access all event instances" do
          Razor::Data::Event.all.each do |event|
            get "/api/collections/events/#{URI::escape(event.name)}"
            last_response.status.should == 200
            validate_schema! event_item_schema, last_response.body
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
      it "should state that 'start', 'limit' and 'depth' are valid parameters" do
        get '/api'
        params = last_response.json['collections'].select {|c| c['name'] == 'events'}.first['params']
        params.should == {'start' => {"type" => "number"}, 'limit' => {"type" => "number"}}.merge(depth_param)
      end
      it "should view all results by default" do
        21.times { Fabricate(:event) }
        get "/api/collections/events"

        last_response.status.should == 200
        events = last_response.json['items']
        events.should be_an_instance_of Array
        events.count.should == 21
        last_response.json['total'].should == 21
        validate_schema! collection_schema, last_response.body
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
        validate_schema! collection_schema, last_response.body
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
        validate_schema! collection_schema, last_response.body
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
        validate_schema! collection_schema, last_response.body
      end
    end

    include_examples "depth parameter tests", "events", event_item_schema do
      let(:generate_coll) { coll_generator_from_fabricate(10, :event) } 
    end
  end
end
