# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdateBrokerConfiguration do
  include Razor::Test::Commands

  before :each do
    use_broker_fixtures
  end

  let(:app) { Razor::App }

  let(:broker) do
    Fabricate(:broker_with_configuration)
  end
  let(:command_hash) do
    {
        'broker' => broker.name,
        'key' => 'optional-key',
        'value' => 'new',
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_config(data)
    command 'update-broker-configuration', data
  end

  it_behaves_like "a command"

  context 'update' do
    [123, '123', ['abc'], {'a' => 123}].each do |new|
      it 'should update a single existing key' do
        command_hash['value'] = new
        update_config(command_hash)
        last_response.status.should == 202
        last_response.json['result'].should == 'value for key optional-key updated'
        broker.reload
        broker.configuration[command_hash['key']].should == new
      end
    end
  end

  context 'clear' do
    it 'should clear a single existing key' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'optional-key'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'key optional-key removed from configuration'
      broker.reload
      broker.configuration.should_not include command_hash['key']
    end
    it 'should reset key with default back to its default' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'key-with-default'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'value for key key-with-default reset to default'
      broker.reload
      broker.configuration[command_hash['key']].should == 1
    end
    it 'should reset an explicitly optional key with default back to its default' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'optional-key-with-default'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'value for key optional-key-with-default reset to default'
      broker.reload
      broker.configuration[command_hash['key']].should == 1
    end

    it 'should fail to clear a required key' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'required-key'
      update_config(command_hash)
      broker.reload
      last_response.json['error'].should == 'cannot clear required configuration key required-key'
      last_response.status.should == 422
      broker.configuration.should include command_hash['key']
    end

    it 'should allow nonexistent keys' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'non-existent'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'no changes; key non-existent already absent'
      broker.reload
      broker.configuration.should_not include command_hash['non-existent']
    end

    context 'changing broker types on the fly' do
      def paths; Razor.config.broker_paths; end
      def path;  paths.first; end

      def with_brokers_in(brokers)
        brokers.each do |root, brokers|
          root = Pathname(root)
          brokers.each do |name, content|
            dir = root + (name + '.broker')
            dir.mkpath
            content.each do |name, innards|
              (dir + name).open('w') {|fh| fh.write innards }
            end
          end
        end
        yield
      end

      # Ensure that we have a clean, empty broker_path to test in.
      around :each do |test|
        Dir.mktmpdir do |dir|
          Razor.config['broker_path'] = dir
          test.run
        end
      end

      initial_config = {'server' => {'required' => false}}

      broker_hash = {'shifty' => {
          'install.erb'        => "# no real content here\n",
          'configuration.yaml' => initial_config.to_yaml}}
      new_broker_hash = {'shifty' => {
          'install.erb'        => "# no real content here\n",
          'configuration.yaml' => {}.to_yaml}}

      it 'should allow clearing of keys not in schema' do
        with_brokers_in(path => broker_hash) do
          brokertype = Razor::BrokerType.find(name: 'shifty')
          broker = Razor::Data::Broker.new(name: 'shifty', broker_type: brokertype, configuration: {'server' => 'abc'}).save

          # Change the brokertype
          with_brokers_in(path => new_broker_hash) do
            update_config({'broker' => broker.name,
                           'key' => 'server',
                           'clear' => true})
            last_response.status.should == 202
            last_response.json['result'].should == 'key server removed from configuration'
          end
        end
      end

      it 'should disallow changing of keys not in schema' do
        with_brokers_in(path => broker_hash) do
          brokertype = Razor::BrokerType.find(name: 'shifty')
          broker = Razor::Data::Broker.new(name: 'shifty', broker_type: brokertype, configuration: {'server' => 'abc'}).save

          # Change the brokertype
          with_brokers_in(path => new_broker_hash) do
            update_config({'broker' => broker.name,
                           'key' => 'server',
                           'value' => 'new-value'})
            last_response.status.should == 422
            last_response.json['error'].should == 'configuration key server is not in the schema and must be cleared'
          end
        end
      end
    end
  end
end
