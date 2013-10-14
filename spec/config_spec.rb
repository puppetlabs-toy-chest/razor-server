require 'spec_helper'
require 'pathname'

describe Razor::Config do
  def make_config(content)
    Dir.mktmpdir do |dir|
      fname = Pathname(dir) + "config.yaml"
      if content
        hash = { 'all' => {} }
        # Break the paths in content into nested hashes
        content.each do |key, value|
          path = key.to_s.split(".")
          last = path.pop
          path.inject(hash['all']) { |v, k| v[k] ||= {}; v[k] if v }[last] = value
        end
        # Write the resulting YAML file
        fname.open('w') { |fh| fh.write hash.to_yaml }
      end
      Razor::Config.new(Razor.env, fname.to_s)
    end
  end

  describe "loading" do
    it "should raise ENOENT for nonexistant config" do
      expect { make_config(nil) }.to raise_error(Errno::ENOENT)
    end

    it "should tolerate an empty config file" do
      make_config({}).should be_an_instance_of(Razor::Config)
    end
  end

  describe "validating" do
    def validate(content)
      key = content.keys.first
      # repo_store_root is mandatory, populate it with a default unless
      # it is set to :none to indicate we want it not set in our test
      if content["repo_store_root"] == :none
        content.delete("repo_store_root")
      else
        content["repo_store_root"] ||= Dir.tmpdir
      end
      make_config(content).validate!
      true
    rescue Razor::InvalidConfigurationError => e
      # The first key in content is the one we are testing; if we get an
      # error about any other key, something strange is happening
      raise e if e.key != key
      false
    end

    describe "facts.blacklist" do
      [ "id", "uptime.*" ].each do |s|
        it "should accept /#{s}/" do
          validate("facts.blacklist" => ["/#{s}/"]).should be_true
        end
      end

      [ "*", "[a-z*" ].each do |s|
        it "should reject /#{s}/" do
          validate("facts.blacklist" => ["/#{s}/"]).should be_false
        end
      end

      [ "*", "[a-z*" ].each do |s|
        it "should accept a literal #{s}" do
          validate("facts.blacklist" => [s]).should be_true
        end
      end
    end

    describe "repo_store_root" do
      it "should require that repo_store_root is set" do
        validate("repo_store_root" => :none).should be_false
      end

      it "should reject a non existing root" do
        Dir.mktmpdir do |dir|
          root = Pathname(dir) + "not_there"
          validate('repo_store_root' => root.to_s).should be_false
        end
      end

      it "should accept an existing directory" do
        Dir.mktmpdir do |dir|
          validate('repo_store_root' => dir).should be_true
        end
      end

      it "should reject a relative path" do
        Dir.mktmpdir do |dir|
          (Pathname(dir) + "sub").mkpath
          Dir.chdir(dir) do
            validate('repo_store_root' => "sub").should be_false
          end
        end
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
