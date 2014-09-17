# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::DeleteHook do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  let(:hook) { Fabricate(:hook)}
  let(:command_hash) { { "name" => hook.name } }
  before :each do
    authorize 'fred', 'dead'
  end

  def delete_hook(name)
    command 'delete-hook', { "name" => name }
  end

  it_behaves_like "a command"

  before :each do
    header 'content-type', 'application/json'
  end

  it "should delete an existing hook" do
    hook = Fabricate(:hook)
    count = Hook.count
    delete_hook(hook.name)

    last_response.status.should == 202
    Hook[:id => hook.id].should be_nil
    Hook.count.should == count-1
  end

  it "should succeed and do nothing for a nonexistent hook" do
    hook = Fabricate(:hook)
    count = Hook.count

    delete_hook(hook.name + "not really")

    last_response.status.should == 202
    Hook.count.should == count
  end
end
