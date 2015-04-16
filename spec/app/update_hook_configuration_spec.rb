# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::UpdateHookConfiguration do
  include Razor::Test::Commands

  use_hook_fixtures

  let(:app) { Razor::App }

  let(:hook) do
    Fabricate(:hook_with_configuration)
  end
  let(:command_hash) do
    {
        'hook' => hook.name,
        'key' => 'optional-key',
        'value' => 'new',
    }
  end

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def update_config(data)
    command 'update-hook-configuration', data
  end

  it_behaves_like "a command"

  context 'update' do
    [123, '123', ['abc'], {'a' => 123}].each do |new|
      it 'should update a single existing key' do
        command_hash['value'] = new
        update_config(command_hash)
        last_response.status.should == 202
        last_response.json['result'].should == 'value for key optional-key updated'
        hook.reload
        hook.configuration[command_hash['key']].should == new
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
      hook.reload
      hook.configuration.should_not include command_hash['key']
    end
    it 'should reset key with default back to its default' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'key-with-default'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'value for key key-with-default reset to default'
      hook.reload
      hook.configuration[command_hash['key']].should == 1
    end
    it 'should reset an explicitly optional key with default back to its default' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'optional-key-with-default'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'value for key optional-key-with-default reset to default'
      hook.reload
      hook.configuration[command_hash['key']].should == 1
    end

    it 'should fail to clear a required key' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'required-key'
      update_config(command_hash)
      hook.reload
      last_response.json['error'].should == 'cannot clear required configuration key required-key'
      last_response.status.should == 422
      hook.configuration.should include command_hash['key']
    end

    it 'should allow nonexistent keys' do
      command_hash['clear'] = true
      command_hash.delete('value')
      command_hash['key'] = 'non-existent'
      update_config(command_hash)
      last_response.status.should == 202
      last_response.json['result'].should == 'no changes; key non-existent already absent'
      hook.reload
      hook.configuration.should_not include command_hash['non-existent']
    end
  end
end
