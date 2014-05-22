# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

describe Razor::Command::DeleteRepo do
  include Razor::Test::Commands

  let(:app) { Razor::App }
  let(:repo) { Fabricate(:repo) }
  let(:command_hash) { { "name" => repo.name } }
  before :each do
    authorize 'fred', 'dead'
  end

  def delete_repo(name)
    command 'delete-repo', { "name" => name }
  end

  context "/api/commands/delete-repo" do
    before :each do
      header 'content-type', 'application/json'
    end

    it_behaves_like "a command"

    it "should delete an existing repo" do
      repo = Fabricate(:repo)
      count = Repo.count
      delete_repo(repo.name)

      last_response.status.should == 202
      Repo[:id => repo.id].should be_nil
      Repo.count.should == count-1
    end

    it "should succeed and do nothing for a nonexistent repo" do
      repo = Fabricate(:repo)
      count = Repo.count

      delete_repo(repo.name + "not really")

      last_response.status.should == 202
      Repo.count.should == count
    end
  end
end
