require 'spec_helper'
require 'pathname'

describe Razor::Config do
  describe "broker_paths" do
    # The default broker path, relative to our app root...
    let :default do File.join(Razor.root, 'brokers') end

    [1, {}, [], {"one" => "two"}, ["one", "two"], ["/bin", "/sbin"]].each do |bad|
      it "should raise if no broker_path is bad: #{bad.inspect}" do
        Razor.config['broker_path'] = bad
        expect { Razor.config.broker_paths }.to raise_error
      end
    end

    it "should default to 'brokers' under the application root" do
      Razor.config.values.delete('broker_path')
      Razor.config.broker_paths.should == [default]
    end

    it "should split paths on ':'" do
      Razor.config['broker_path'] = '/one:/two'
      Razor.config.broker_paths.should == ['/one', '/two']
    end

    it "should work if only a single path is specified" do
      Razor.config['broker_path'] = '/one'
      Razor.config.broker_paths.should == ['/one']
    end

    it "should make relative paths absolute, from the app root" do
      Razor.config['broker_path'] = 'one'
      Razor.config.broker_paths.should == [File.join(Razor.root, 'one')]
    end

    it "should handle a mix of relative and absolute paths" do
      Razor.config['broker_path'] = '/one:two:/three'
      Razor.config.broker_paths.should == ['/one', File.join(Razor.root, 'two'), '/three']
    end

    it "should handle relative paths" do
      Razor.config['broker_path'] = '../one'
      Razor.config.broker_paths.should == [(Pathname(Razor.root) + '../one').to_s]
    end

    it "should ignore the first path component being empty" do
      Razor.config['broker_path'] = ':/two:/three'
      Razor.config.broker_paths.should == ['/two', '/three']
    end

    it "should ignore a middle path component being empty" do
      Razor.config['broker_path'] = '/one::/three'
      Razor.config.broker_paths.should == ['/one', '/three']
    end

    it "should ignore the final path component being empty" do
      Razor.config['broker_path'] = '/one:/two:'
      Razor.config.broker_paths.should == ['/one', '/two']
    end
  end
end
