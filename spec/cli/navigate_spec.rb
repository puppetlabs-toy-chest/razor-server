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
      nav.get_document.should_not be_nil
      nav.get_document.should == nav.entrypoint
    end
  end

  context "with a single item path" do
    subject(:nav) {Razor::CLI::Parse.new(["tags"]).navigate}
    it { nav.get_document.should == []}

    it do
      nav.get_document;
      nav.last_url.to_s.should == "http://example.org/api/collections/tags"
    end
  end

  context "with an invalid path" do
    subject(:nav) {Razor::CLI::Parse.new(["going","nowhere"]).navigate}

    it {expect{nav.get_document}.to raise_error Razor::CLI::NavigationError}
  end

  describe "extract_command" do
    it "should understand --arg=value"
    it "should understand '--arg value'"
  end
end
