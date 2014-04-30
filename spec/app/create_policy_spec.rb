# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe "create policy command" do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-policy" do
    before :each do
      use_task_fixtures
      header 'content-type', 'application/json'
    end

    let(:repo)   { Fabricate(:repo) }
    let(:broker) { Fabricate(:broker) }

    let (:tag1) { Fabricate(:tag) }

    let(:policy_hash) do
      # FIXME: Once we have proper helpers to generate these URL's,
      # use them in these tests
      { :name          => "test policy",
        :repo          => { "name" => repo.name },
        :task          => {"name" => "some_os"},
        :broker        => { "name" => broker.name },
        :hostname      => "host${id}.example.com",
        'root-password' => "geheim",
        :tags          => [ { "name" => tag1.name } ]
      }
    end

    def create_policy(input = nil)
      input ||= policy_hash
      command 'create-policy', input
    end

    # Successful creation
    it "should return 202, and the URL of the policy" do
      create_policy

      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[id name spec]

      last_response.json["id"].should =~ %r'/api/collections/policies/test%20policy\Z'
    end

    it "should fail if 'tags' is wrong datatype" do
      policy_hash[:tags] = ''
      create_policy
      last_response.status.should == 422
    end

    it "should fail if a nonexisting tag is referenced" do
      policy_hash[:tags] = [ { "name" => "not_a_tag"} ]
      create_policy
      last_response.json['error'].should =~ /A rule must be provided for new tag 'not_a_tag'/
      last_response.status.should == 400
    end

    it "should fail if a nonexisting repo is referenced" do
      policy_hash[:repo] = { "name" => "not_an_repo" }
      create_policy
      last_response.status.should == 404
    end

    it "should fail if the name is empty" do
      policy_hash[:name] = ""
      create_policy
      last_response.status.should == 422
    end

    it "should fail if the name is missing" do
      policy_hash.delete(:name)
      create_policy
      last_response.status.should == 422
    end

    it "should fail if the root password is missing" do
      policy_hash.delete('root-password')
      create_policy
      last_response.status.should == 422
    end

    it "should conform root password's legacy syntax" do
      policy_hash['root_password'] = policy_hash.delete('root-password')
      create_policy
      last_response.status.should == 202
    end

    it "should create a policy in the database" do
      create_policy

      Razor::Data::Policy[:name => policy_hash[:name]].should be_an_instance_of Razor::Data::Policy
    end

    it "should default to enabling the policy" do
      create_policy

      Razor::Data::Policy[:name => policy_hash[:name]].enabled.should be_true
    end

    it "should allow creating a disabled policy" do
      policy_hash[:enabled] = false

      create_policy

      Razor::Data::Policy[:name => policy_hash[:name]].enabled.should be_false
    end

    it "should allow creating a policy with max count" do
      policy_hash['max-count'] = 10

      create_policy

      Razor::Data::Policy[:name => policy_hash[:name]].max_count.should == 10
    end

    it "should fail with the wrong datatype for repo" do
      policy_hash[:repo] = { }
      create_policy
      last_response.json['error'].should =~ /repo\.name is a required attribute, but it is not present/
    end

    it "should fail with the wrong datatype for max-count" do
      policy_hash['max-count'] = { }
      create_policy
      last_response.json['error'].should =~ /max-count should be a number, but was actually a object/
    end


    it "should conform max count's legacy syntax" do
      policy_hash['max_count'] = 10
      create_policy
      last_response.status.should == 202
    end

    it "should fail with the wrong datatype for task" do
      policy_hash[:task] = { }
      create_policy
      last_response.json['error'].should =~ /task\.name is a required attribute, but it is not present/
    end

    it "should fail with the wrong datatype for broker" do
      policy_hash[:broker] = { }
      create_policy
      last_response.json['error'].should =~ /broker\.name is a required attribute, but it is not present/
    end

    it "should fail with the wrong datatype for tags" do
      policy_hash[:tags] = { }
      create_policy
      last_response.json['error'].should =~ /tags should be a array, but was actually a object/
      policy_hash[:tags] = [ { } ]
      create_policy
      last_response.json['error'].should =~ /tags\[0\].name is a required attribute, but it is not present/
    end

    it "should conform the shortcut syntax" do
      policy_hash[:repo] = repo.name
      policy_hash[:task] = 'some_os'
      policy_hash[:broker] = broker.name
      policy_hash[:tags] = [ tag1.name ]

      create_policy

      last_response.json['error'].should be_nil
      Razor::Data::Policy[:name => policy_hash[:name]].should be_an_instance_of Razor::Data::Policy
    end

    it "should allow mixed forms" do
      policy_hash[:repo] = { 'name' => repo.name }
      policy_hash[:task] = 'some_os'
      policy_hash[:broker] = { 'name' => broker.name }
      policy_hash[:tags] = [ tag1.name, {'name' => tag1.name} ]

      create_policy

      last_response.json['error'].should be_nil
      Razor::Data::Policy[:name => policy_hash[:name]].should be_an_instance_of Razor::Data::Policy
    end

    context "ordering" do
      before(:each) do
        @p1 = Fabricate(:policy)
        @p2 = Fabricate(:policy)
      end

      def check_order(where, policy, list)
        policy_hash[where.to_s] = { "name" => policy.name } unless where.nil?
        create_policy
        last_response.status.should == 202
        p = Razor::Data::Policy[:name => policy_hash[:name]]

        list = list.map { |x| x == :_ ? p.id : x.id }
        Policy.all.map { |p| p.id }.should == list
      end

      it "should append to the policy list by default" do
        check_order nil, nil, [@p1, @p2, :_]
      end

      describe 'before' do
        it "p1 creates at the head of the table" do
          check_order(:before, @p1, [:_, @p1, @p2])
        end

        it "p2 goes between p1 and p2" do
          check_order(:before, @p2, [@p1, :_, @p2])
        end
      end

      describe "after" do
        it "p1 goes between p1 and p2" do
          check_order(:after, @p1, [@p1, :_, @p2])
        end

        it "p2 goes to the end of the table" do
          check_order(:after, @p2, [@p1, @p2, :_])
        end
      end
    end

    context "creating references" do
      it "creates tags that have rules" do
        policy_hash[:tags] = [
            {'name' => 'small', 'rule' => ['<=', ['num', %w(fact processorcount)], 2]}
        ]

        create_policy

        Razor::Data::Tag.find(name: 'small').should_not be_nil
      end
      it "fails when rule does not match existing rule" do
        policy_hash[:tags] = [
            {'name' => tag1.name, 'rule' => ['<=', ['num', %w(fact processorcount)], 2]}
        ]

        create_policy

        last_response.json['error'].should =~ /Provided rule and existing rule for existing tag '#{tag1.name}' must be equal/
      end
    end
  end
end
