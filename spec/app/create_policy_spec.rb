# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "create policy command" do
  include Razor::Test::Commands

  let('app') { Razor::App }
  before 'each' do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-policy" do
    before 'each' do
      use_task_fixtures
      header 'content-type', 'application/json'
    end

    let(:repo)   { Fabricate('repo') }
    let(:broker) { Fabricate('broker') }

    let (:tag1) { Fabricate('tag') }

    let('command_hash') do
      # FIXME: Once we have proper helpers to generate these URL's,
      # use them in these tests
      { 'name'          => "test policy",
        'repo'          => repo.name,
        'task'          => 'some_os',
        'broker'        => broker.name,
        'hostname'      => "host${id}.example.com",
        'root-password' => "geheim",
        'tags'          => [ tag1.name ]
      }
    end

    describe Razor::Command::CreatePolicy do
      it_behaves_like "a command"
    end

    def create_policy(input = nil)
      input ||= command_hash
      command 'create-policy', input
    end

    # Successful creation
    it "should return 202, and the URL of the policy" do
      create_policy

      last_response.status.should == 202
      last_response.json.keys.should =~ %w[id name spec]

      last_response.json["id"].should =~ %r'/api/collections/policies/test%20policy\Z'
    end

    it "should fail if 'tags' is wrong datatype" do
      command_hash['tags'] = ''
      create_policy
      last_response.status.should == 422
    end

    it "should fail if a nonexisting tag is referenced" do
      command_hash['tags'] = [ { "name" => "not_a_tag"} ]
      create_policy
      last_response.json['error'].should == "tags[0] must be the name of an existing tag, but is 'not_a_tag'"
      last_response.status.should == 404
    end

    it "should fail if a nonexisting repo is referenced" do
      command_hash['repo'] = { "name" => "not_an_repo" }
      create_policy
      last_response.status.should == 404
    end

    it "should fail if the name is empty" do
      command_hash['name'] = ""
      create_policy
      last_response.status.should == 422
    end

    it "should fail if the name is missing" do
      command_hash.delete('name')
      create_policy
      last_response.status.should == 422
    end

    it "should fail if the root password is missing" do
      command_hash.delete('root-password')
      create_policy
      last_response.status.should == 422
    end

    it "should fail without repo" do
      command_hash.delete('repo')
      create_policy
      last_response.status.should == 422
      last_response.json['error'].should == "repo is a required attribute, but it is not present"
    end

    it "should fail without broker" do
      command_hash.delete('broker')
      create_policy
      last_response.status.should == 422
      last_response.json['error'].should == "broker is a required attribute, but it is not present"
    end

    it "should conform root password's legacy syntax" do
      command_hash['root_password'] = command_hash.delete('root-password')
      create_policy
      last_response.status.should == 202
    end

    it "should create a policy in the database" do
      create_policy

      Razor::Data::Policy[:name => command_hash['name']].should be_an_instance_of Razor::Data::Policy
    end

    it "should default to enabling the policy" do
      create_policy

      Razor::Data::Policy[:name => command_hash['name']].enabled.should be_true
    end

    it "should allow creating a disabled policy" do
      command_hash['enabled'] = false

      create_policy

      Razor::Data::Policy[:name => command_hash['name']].enabled.should be_false
    end

    it "should allow creating a policy with max count" do
      command_hash['max-count'] = 10

      create_policy

      Razor::Data::Policy[:name => command_hash['name']].max_count.should == 10
    end

    it "should allow creating a policy with node_metadata" do
      metadata = { "key1" => "value1", "key2" => "value2" }
      command_hash['node-metadata'] = metadata
      create_policy
      Razor::Data::Policy[:name => command_hash['name']].node_metadata.should == metadata
    end

    it "should fail with the wrong datatype for repo" do
      command_hash['repo'] = { }
      create_policy
      last_response.json['error'].should == 'repo should be a string, but was actually a object'
    end

    it "should fail with the wrong datatype for max-count" do
      command_hash['max-count'] = { }
      create_policy
      last_response.json['error'].should =~ /max-count should be a number, but was actually a object/
    end


    it "should conform max count's legacy syntax" do
      command_hash['max_count'] = 10
      create_policy
      last_response.status.should == 202
    end

    it "should conform tag array into tags" do
      tag2 = Fabricate('tag')
      command_hash['tag'] = [tag2.name]
      create_policy
      last_response.status.should == 202
      ([tag1, tag2] & Razor::Data::Policy[:name => command_hash['name']].tags).should == [tag1, tag2]
    end

    it "should conform tag string into tags" do
      tag2 = Fabricate('tag')
      command_hash['tag'] = tag2.name
      create_policy
      last_response.status.should == 202
      ([tag1, tag2] & Razor::Data::Policy[:name => command_hash['name']].tags).should == [tag1, tag2]
    end

    it "should fail with the wrong datatype for tag" do
      command_hash['tag'] = 123
      create_policy
      last_response.json['error'].should == "tags[1] should be a string, but was actually a number"
      last_response.status.should == 422
    end

    it "should fail with the wrong datatype for task" do
      command_hash['task'] = { }
      create_policy
      last_response.json['error'].should == 'task should be a string, but was actually a object'
    end

    it "should fail with the wrong datatype for broker" do
      command_hash['broker'] = { }
      create_policy
      last_response.json['error'].should == 'broker should be a string, but was actually a object'
    end

    it "should fail with the wrong datatype for tags" do
      command_hash['tags'] = { }
      create_policy
      last_response.json['error'].should == 'tags should be a array, but was actually a object'
      command_hash['tags'] = [ { } ]
      create_policy
      last_response.json['error'].should == 'tags[0] should be a string, but was actually a object'
    end

    it "should conform the long syntax" do
      command_hash['repo'] = {'name' => repo.name}
      command_hash['task'] = {'name' => 'some_os'}
      command_hash['broker'] = {'name' => broker.name}
      command_hash['tags'] = [ {'name' => tag1.name} ]

      create_policy

      last_response.json['error'].should be_nil
      Razor::Data::Policy[:name => command_hash['name']].should be_an_instance_of Razor::Data::Policy
    end

    it "should allow mixed forms" do
      command_hash['repo'] = { 'name' => repo.name }
      command_hash['task'] = 'some_os'
      command_hash['broker'] = { 'name' => broker.name }
      command_hash['tags'] = [ tag1.name, {'name' => tag1.name} ]

      create_policy

      last_response.json['error'].should be_nil
      Razor::Data::Policy[:name => command_hash['name']].should be_an_instance_of Razor::Data::Policy
    end

    it "should return 202 if the policy is identical" do
      create_policy
      create_policy

      last_response.json['error'].should be_nil
      last_response.json['name'].should == command_hash['name']
      last_response.status.should == 202
    end

    it "should return 409 if the policy is not identical" do
      create_policy
      other_repo = Fabricate(:repo)
      other_broker = Fabricate(:broker)
      command_hash['repo'] = other_repo.name
      command_hash['broker'] = other_broker.name

      create_policy

      last_response.json['error'].should ==
          "The policy #{command_hash['name']} already exists, and the repo_id, broker_id fields do not match"
      last_response.status.should == 409
    end

    context "ordering" do
      before('each') do
        @p1 = Fabricate('policy')
        @p2 = Fabricate('policy')
      end

      def check_order(where, policy, list)
        command_hash[where.to_s] = { "name" => policy.name } unless where.nil?
        create_policy
        last_response.status.should == 202
        p = Razor::Data::Policy[:name => command_hash['name']]

        list = list.map { |x| x == '_' ? p.id : x.id }
        Policy.all.map { |p| p.id }.should == list
      end

      it "should append to the policy list by default" do
        check_order nil, nil, [@p1, @p2, '_']
      end

      describe 'before' do
        it "p1 creates at the head of the table" do
          check_order('before', @p1, ['_', @p1, @p2])
        end

        it "p2 goes between p1 and p2" do
          check_order('before', @p2, [@p1, '_', @p2])
        end
      end

      describe "after" do
        it "p1 goes between p1 and p2" do
          check_order('after', @p1, [@p1, '_', @p2])
        end

        it "p2 goes to the end of the table" do
          check_order('after', @p2, [@p1, @p2, '_'])
        end
      end
    end
  end
end
