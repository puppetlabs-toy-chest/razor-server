require_relative '../spec_helper'
require_relative '../../lib/razor/cli'

describe Razor::CLI::Siren do
  Action = Razor::CLI::Siren::Action

  describe Action do
    subject(:act) do
      Action.parse("name" => "create", "fields" => [
        { "name" => "one", "value" => "ten" },
        { "name" => "name-with-dashes", "value"=> "underscores"}
      ])
    end

    context "with --arg=value" do
      it do
        act.optparse.parse!(["--one=1", "--name-with-dashes=too many"])
        act.fields.map{|f| [f.name, f.value]}.should == [
          ["one", "1"],
          ["name-with-dashes", "too many"]
        ]
      end
    end

    context "with '--arg value'" do
      it do
        act.optparse.parse!(%w"--one 1 --name-with-dashes yes")
        act.fields.map{|f| [f.name, f.value]}.should == [
          ["one", "1"],
          ["name-with-dashes", "yes"]
        ]
      end
    end

    context "with unknown flags" do
      it do
        expect {act.optparse.parse!(%w"--yes up")}.to raise_error OptionParser::InvalidOption
      end
    end

    context "with missing flags" do
      it "should use the default values" do
        act.optparse.parse!(%w"--one up")
        act.fields.map{|f| [f.name, f.value]}.should == [
          ["one", "up"],
          ["name-with-dashes", "underscores"]
        ]
      end
    end
  end
end
