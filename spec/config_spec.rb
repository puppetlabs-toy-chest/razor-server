require 'spec_helper'
require 'pathname'

describe Razor::Config do
  def with_config(content, &block)
    Dir.mktmpdir do |dir|
      fname = Pathname(dir) + "config.yaml"
      if content
        fname.open('w') { |fh| fh.write content.to_yaml }
      end
      config = Razor::Config.new(Razor.env, fname.to_s)
      yield(config) if block_given?
    end
  end

  describe "loading config" do
    it "should raise ENOENT for nonexistant config" do
      expect { with_config(nil) }.to raise_error(Errno::ENOENT)
    end

    it "should tolerate an empty config file" do
      with_config({}) do |config|
        config.should be_an_instance_of(Razor::Config)
      end
    end
  end

  shared_examples "expanding paths" do |setting|
    let :setting_name    do setting + '_path' end
    let :setting_default do File.join(Razor.root, setting + 's') end

    [1, {}, [], {"one" => "two"}, ["one", "two"], ["/bin", "/sbin"]].each do |bad|
      it "should raise if #{setting}_path is bad: #{bad.inspect}" do
        Razor.config[setting_name] = bad
        expect { Razor.config.send(setting_name + 's') }.to raise_error
      end
    end

    it "should default to 'brokers' under the application root" do
      Razor.config.values.delete(setting_name)
      Razor.config.send(setting_name + 's').should == [setting_default]
    end

    it "should split paths on ':'" do
      Razor.config[setting_name] = '/one:/two'
      Razor.config.send(setting_name + 's').should == ['/one', '/two']
    end

    it "should work if only a single path is specified" do
      Razor.config[setting_name] = '/one'
      Razor.config.send(setting_name + 's').should == ['/one']
    end

    it "should make relative paths absolute, from the app root" do
      Razor.config[setting_name] = 'one'
      Razor.config.send(setting_name + 's').should == [File.join(Razor.root, 'one')]
    end

    it "should handle a mix of relative and absolute paths" do
      Razor.config[setting_name] = '/one:two:/three'
      Razor.config.send(setting_name + 's').should == ['/one', File.join(Razor.root, 'two'), '/three']
    end

    it "should handle relative paths" do
      Razor.config[setting_name] = '../one'
      Razor.config.send(setting_name + 's').should == [(Pathname(Razor.root) + '../one').to_s]
    end

    it "should ignore the first path component being empty" do
      Razor.config[setting_name] = ':/two:/three'
      Razor.config.send(setting_name + 's').should == ['/two', '/three']
    end

    it "should ignore a middle path component being empty" do
      Razor.config[setting_name] = '/one::/three'
      Razor.config.send(setting_name + 's').should == ['/one', '/three']
    end

    it "should ignore the final path component being empty" do
      Razor.config[setting_name] = '/one:/two:'
      Razor.config.send(setting_name + 's').should == ['/one', '/two']
    end
  end

  describe "installer_paths" do
    it_behaves_like "expanding paths", 'installer'
  end

  describe "broker_paths" do
    it_behaves_like "expanding paths", 'broker'
  end
end
