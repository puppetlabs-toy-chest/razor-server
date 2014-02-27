# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

# This should eventually be done by a command line tool resp. the server
# when adding an task. For now, we use it to sanity check the
# file-based tasks that we have
describe "stock task" do
  include Rack::Test::Methods

  TASK_PATH = File::join(Razor.root, "tasks")
  TASK_NAMES = Dir::glob(File::join(TASK_PATH, "*.yaml")).map do |path|
    File::basename(path, ".yaml")
  end

  def app
    Razor::App
  end

  before :each do
    authorize 'fred', 'dead'
  end

  TASK_NAMES.each do |name|
    describe name do
      before(:each) do
        Razor.config["task_path"] = TASK_PATH

        @node = Fabricate(:node, :hw_info => ["mac=001122334455"])
        policy = Fabricate(:policy, :task_name => name)
        @node.bind(policy)
        @node.save
      end

      let(:task) { Razor::Task.find(name) }

      it "can be loaded" do
        task.should_not be_nil
      end

      Dir::glob(File::join(TASK_PATH, name, "**/*.erb")).map do |fn|
        File::basename(fn, ".erb")
      end.each do |templ|
        it "can load the #{templ} template" do
          get "/svc/file/#{@node.id}/#{templ}"
          last_response.status.should == 200
          last_response.body.should_not be_empty
        end
      end
    end
  end
end
