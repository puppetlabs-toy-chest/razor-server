require_relative '../spec_helper'
require_relative '../../app'
require_relative '../../lib/razor/cli'

describe Razor::CLI::Parse do

  def parse(*args)
    Razor::CLI::Parse.new(args)
  end

  describe "#new" do
    context "with no arguments" do
      it {parse.show_help?.should be true}
    end

    context "with a '-h'" do
      it {parse("-h").show_help?.should be true}
    end

    context "with a '-d'" do
      it {parse("-d").dump_response?.should be true}
    end

    context "with a '-U'" do
      it "should use the given URL" do
        url = 'http://razor.example.com:2150/path/to/api'
        parse('-U',url).api_url.to_s.should == url
      end
    end
  end

  describe "#navigate" do
    it {parse.navigate.should be_a Razor::CLI::Navigate}
  end
end
