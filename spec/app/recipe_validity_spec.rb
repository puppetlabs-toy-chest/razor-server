require_relative '../spec_helper'
require_relative '../../app'

# This should eventually be done by a command line tool resp. the server
# when adding an recipe. For now, we use it to sanity check the
# file-based recipes that we have
describe "stock recipe" do
  include Rack::Test::Methods

  RECIPE_PATH = File::join(Razor.root, "recipes")
  RECIPE_NAMES = Dir::glob(File::join(RECIPE_PATH, "*.yaml")).map do |path|
    File::basename(path, ".yaml")
  end

  def app
    Razor::App
  end

  before :each do
    authorize 'fred', 'dead'
  end

  RECIPE_NAMES.each do |name|
    describe name do
      before(:each) do
        Razor.config["recipe_path"] = RECIPE_PATH

        @node = Fabricate(:node, :hw_info => ["mac=001122334455"])
        policy = Fabricate(:policy, :recipe_name => name)
        @node.bind(policy)
        @node.save
      end

      let(:recipe) { Razor::Recipe.find(name) }

      it "can be loaded" do
        recipe.should_not be_nil
      end

      Dir::glob(File::join(RECIPE_PATH, name, "**/*.erb")).map do |fn|
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
