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
  end
end
