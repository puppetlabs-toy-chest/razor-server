require_relative '../spec_helper'
require_relative '../../app'
require_relative '../../lib/razor/cli'

describe Razor::CLI::Navigate do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before(:each) do
    RestClient.instance_variable_set :@rack_get, Proc.new {|*args| get(*args) }
  end

  module ::RestClient
    def self.get(url, headers ={})
      a = @rack_get.call(URI.parse(url.to_s).path,headers)
      def a.headers
        Hash[@header.map {|name, value| [name.downcase.gsub("-","_").to_sym, value] }]
      end
      a
    end
  end

  let(:app) {Razor::App}

  context "with no path" do
    subject(:nav) {Razor::CLI::Parse.new([]).navigate}
    it do
      nav.get_final_object.should_not be_nil
      nav.get_final_object.should == nav.entrypoint
    end
  end

  context "with a single item path" do
    subject(:nav) {Razor::CLI::Parse.new(["tags"]).navigate}
    it { nav.get_final_object.entities.should == []}

    it do
      nav.get_final_object;
      nav.last_url.to_s.should == "http://example.org/api/collections/tags"
    end
  end

  context "with an action path" do
    subject(:nav) {Razor::CLI::Parse.new(["tags", "create"]).navigate}

    it {nav.get_final_object.should be_a Razor::CLI::Siren::Action}
  end

  context "with an invalid path" do
    subject(:nav) {Razor::CLI::Parse.new(["going","nowhere"]).navigate}

    it {expect{nav.get_final_object}.to raise_error Razor::CLI::NavigationError}
  end

  describe "extract_command" do
    subject(:nav) {Razor::CLI::Parse.new(["tags"]).navigate}
    subject(:act) {Razor::CLI::Siren::Action.parse "name" => "create"}

    it "should understand --arg=value" do
      args = nav.extract_arguments(act, ["--one=1", "--two=two", "--three=too_many"])
      args.should == { "one"=>"1", "two" => "two", "three" => "too_many"}
    end

    it "should understand '--arg value'" do
      args = nav.extract_arguments(act, %w"--ex 1 --why maybe --zee yes")
      args.should == { "ex"=>"1", "why" => "maybe", "zee" => "yes"}
    end
  end
end
