# -*- encoding: utf-8 -*-
require 'spec_helper'
require 'tmpdir'
require 'yaml'

describe Razor::BrokerType do
  def paths; Razor.config.broker_paths; end
  def path;  paths.first; end

  def with_brokers_in(brokers)
    brokers.each do |root, brokers|
      root = Pathname(root)
      brokers.each do |name, content|
        dir = root + (name + '.broker')
        dir.mkpath
        content.each do |name, innards|
          (dir + name).open('w') {|fh| fh.write innards }
        end
      end
    end
    yield
  end

  describe "all" do
    context "with one broker_path entry" do
      # Ensure that we have a clean, empty broker_path to test in.
      around :each do |test|
        Dir.mktmpdir do |dir|
          Razor.config['broker_path'] = dir
          test.run
        end
      end

      it "should return the empty set for an empty path" do
        Razor::BrokerType.all.should == []
      end

      it "should return one broker if one exists" do
        broker = {'test' => {'install' => "#!/bin/sh\nexit 0\n"}}
        with_brokers_in(paths.first => broker) do
          Razor::BrokerType.all.should == ['test']
        end
      end

      it "should return two brokers if two exist" do
        brokers = {'one' => {}, 'two' => {}}
        with_brokers_in(paths.first => brokers) do
          Razor::BrokerType.all.should =~ ['one', 'two']
        end
      end

      it "should ignore non-directories with a broker-like name" do
        root = Pathname(paths.first)
        (root + 'ignored.broker').open('w') {|fh| fh.puts "whee!"}
        Razor::BrokerType.all.should == []
      end

      it "should look through symlinks and treat them as brokers" do
        brokers = {'one' => {}, 'two' => {}}
        with_brokers_in(paths.first => brokers) do
          (Pathname(paths.first) + 'symlink.broker').make_symlink('one.broker')
          Razor::BrokerType.all.should =~ ['one', 'two', 'symlink']
        end
      end
    end

    context "with two broker paths" do
      around :each do |test|
        Dir.mktmpdir do |dir1|
          Dir.mktmpdir do |dir2|
            Razor.config['broker_path'] = dir1 + ':' + dir2
            test.run
          end
        end
      end

      it "should return the empty set for an empty path" do
        Razor::BrokerType.all.should == []
      end

      it "should return one broker if one exists in the first path" do
        broker = {'test' => {'install' => "#!/bin/sh\nexit 0\n"}}
        with_brokers_in(paths.first => broker) do
          Razor::BrokerType.all.should == ['test']
        end
      end

      it "should return one broker if one exists in the last path" do
        broker = {'test' => {'install' => "#!/bin/sh\nexit 0\n"}}
        with_brokers_in(paths.last => broker) do
          Razor::BrokerType.all.should == ['test']
        end
      end

      it "should return one record for shadowed brokers" do
        broker = {'test' => {'install' => "#!/bin/sh\nexit 0\n"}}
        with_brokers_in(paths.first => broker, paths.last => broker) do
          Razor::BrokerType.all.should == ['test']
        end
      end
    end
  end

  describe "find" do
    context "with one broker path" do
      around :each do |test|
        Dir.mktmpdir do |dir|
          Razor.config['broker_path'] = dir
          test.run
        end
      end

      it "should return nil if the broker is not found" do
        Razor::BrokerType.find(name: 'foo').should be_nil
      end

      it "should return nil if the broker is a file, because it is ignored" do
        fake = (Pathname(Razor.config.broker_paths.first) + 'test.broker')
        fake.open('w') {|f| f.puts "this is not a valid broker" }
        Razor::BrokerType.find(name: 'foo').should be_nil
      end

      it "should return a Razor::BrokerType if the broker is found" do
        broker = {'test' => {'install.erb' => "# no real content here\n"}}
        with_brokers_in(paths.first => broker) do
          Razor::BrokerType.find(name: 'test').should be_an_instance_of Razor::BrokerType
        end
      end

      it "should raise if the install template is missing" do
        broker = {'test' => {}}
        with_brokers_in(paths.first => broker) do
          expect {
            Razor::BrokerType.find(name: 'test')
          }.to raise_error Razor::BrokerTypeInvalidError, 'test has no install script template'
        end
      end

      it "should raise if the install template is present but unreadable" do
        broker = {'test' => {'install.erb' => "# no real content here\n"}}
        with_brokers_in(paths.first => broker) do
          (Pathname(paths.first) + 'test.broker' + 'install.erb').chmod(0000)
          expect {
            Razor::BrokerType.find(name: 'test')
          }.to raise_error Razor::BrokerTypeInvalidError, 'test has install template install.erb, but it is unreadable'
        end
      end
    end

    context "with three broker paths" do
      around :each do |test|
        Dir.mktmpdir do |dir1|
          Dir.mktmpdir do |dir2|
            Dir.mktmpdir do |dir3|
              Razor.config['broker_path'] = [dir1, dir2, dir3].join(':')
              test.run
            end
          end
        end
      end

      {'first' => 0, 'second' => 1, 'last' => 2}.each do |text, slot|
        it "should find a broker in the #{text} path" do
          broker = {'test' => {'install.erb' => "# no real content here\n"}}
          with_brokers_in(paths[slot] => broker) do
            Razor::BrokerType.find(name: 'test').should be_an_instance_of Razor::BrokerType
          end
        end
      end

      it "should find the first broker when shadowing" do
        first  = {'test' => {'install.erb' => "# this is the first broker\n"}}
        second = {'test' => {'install.erb' => "# this is the second broker\n"}}
        with_brokers_in(paths.first => first, paths.last => second) do
          broker = Razor::BrokerType.find(name: 'test')
          broker.should be_an_instance_of Razor::BrokerType
          broker.name.should == 'test'
          broker.send(:install_template_path, 'install').to_s.should start_with(paths.first)
        end
      end

      it "should find the right broker when several exist" do
        brokers = {
          'one'   => {'install.erb' => "# no real content here\n"},
          'two'   => {'install.erb' => "# no real content here\n"},
          'three' => {'install.erb' => "# no real content here\n"}
        }
        with_brokers_in(paths[1] => brokers) do
          brokers.keys.each do |name|
            Razor::BrokerType.find(name: name).name.should == name
          end
        end
      end

      it "should find all brokers named in `all`" do
        brokers = {
          'one'   => {'install.erb' => "# no real content here\n"},
          'two'   => {'install.erb' => "# no real content here\n"},
          'three' => {'install.erb' => "# no real content here\n"}
        }
        with_brokers_in(paths[1] => brokers) do
          Razor::BrokerType.all.each do |name|
            Razor::BrokerType.find(name: name).name.should == name
          end
        end
      end
    end
  end

  context 'finding install script' do
    around :each do |test|
      Dir.mktmpdir do |dir|
        Razor.config['broker_path'] = dir
        test.run
      end
    end

    it "should find the powershell script if specified" do
      brokers = {'test' => {'install.erb' => "# this is the bash broker\n",
                            'install.ps1.erb' => "# this is the powershell broker\n"}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)
        node.policy.broker.install_script_for(node, 'install.ps1').to_s.should == "# this is the powershell broker\n"
      end
    end

    it "should find the powershell script if '.erb' is included" do
      brokers = {'test' => {'install.erb' => "# this is the bash broker\n",
                            'install.ps1.erb' => "# this is the powershell broker\n"}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)
        node.policy.broker.install_script_for(node, 'install.ps1.erb').to_s.should == "# this is the powershell broker\n"
      end
    end

    it "should find the bash script if specified" do
      brokers = {'test' => {'install.erb' => "# this is the bash broker\n",
                            'install.ps1.erb' => "# this is the powershell broker\n"}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)
        node.policy.broker.install_script_for(node, 'install').to_s.should == "# this is the bash broker\n"
      end
    end

    it "should find the bash script if not specified" do
      brokers = {'test' => {'install.erb' => "# this is the bash broker\n",
                            'install.ps1.erb' => "# this is the powershell broker\n"}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)
        node.policy.broker.install_script_for(node).to_s.should == "# this is the bash broker\n"
      end
    end

    it "should fail if the requested file does not exist" do
      brokers = {'test' => {'install.erb' => "# this is the bash broker\n",
                            'install.ps1.erb' => "# this is the powershell broker\n"}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)
        expect { node.policy.broker.install_script_for(node, 'does-not-exist') }.
            to raise_error(Razor::InstallTemplateNotFoundError,
                           "could not find install template 'does-not-exist.erb' for broker 'test'")
      end
    end

    it "should throw error if 'install.erb' does not exist but is expected" do
      brokers = {'test' => {'install.ps1.erb' => '# some powershell script'}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)

        expect { node.policy.broker.install_script_for(node, 'install') }.
            to raise_error(Razor::InstallTemplateNotFoundError,
                           'could not find install template \'install.erb\' for broker \'test\'')
      end
    end

    it "should return the correct powershell script" do
      brokers = {'test' => {'install.ps1.erb' => '# some powershell script'}}
      with_brokers_in(path => brokers) do
        brokertype = Razor::BrokerType.find(name: 'test')
        task = Fabricate(:task)
        broker = Razor::Data::Broker.new(name: 'test', broker_type: brokertype).save
        policy = Fabricate(:policy, task_name: task.name, broker: broker)
        node = Fabricate(:bound_node, :policy => policy)

        node.policy.broker.install_script_for(node, 'install.ps1').should == '# some powershell script'
      end
    end
  end

  context "configuration_schema" do
    around :each do |test|
      Dir.mktmpdir do |dir|
        Razor.config['broker_path'] = dir
        test.run
      end
    end


    it "should return an empty hash with no configuration data" do
      broker = {'test' => {'install.erb' => "# no real content here\n",}}
      with_brokers_in(path => broker) do
        Razor::BrokerType.find(name: 'test').configuration_schema.should == {}
      end
    end

    it "should return data from the YAML file if it exists" do
      config = {'server' => {'required' => false}}

      broker = {'test' => {
          'install.erb'        => "# no real content here\n",
          'configuration.yaml' => config.to_yaml}}

      with_brokers_in(path => broker) do
        Razor::BrokerType.find(name: 'test').configuration_schema.should == config
      end
    end

    it "should raise if the YAML file is invalid" do
      broker = {'test' => {
          'install.erb'        => "# no real content here\n",
          'configuration.yaml' => "boom: %foo%\n"}}

      with_brokers_in(path => broker) do
        expect {
          Razor::BrokerType.find(name: 'test').configuration_schema
        }.to raise_error Psych::SyntaxError
      end
    end

    it "should return a blank schema if the file is blank" do
      broker = {'test' => {'install.erb' => "# no real content here\n",
                           'configuration.yaml' => nil}}
      with_brokers_in(path => broker) do
        Razor::BrokerType.find(name: 'test').configuration_schema.should == {}
      end
    end
    it "should return a blank schema if the file just has a yaml header" do
      broker = {'test' => {'install.erb' => "# no real content here\n",
                           'configuration.yaml' => '---'}}
      with_brokers_in(path => broker) do
        Razor::BrokerType.find(name: 'test').configuration_schema.should == {}
      end
    end
  end

  context "install_script" do
    around :each do |test|
      Dir.mktmpdir do |dir|
        Razor.config['broker_path'] = dir
        test.run
      end
    end

    def broker_instance_for(that, configuration = nil)
      b = Razor::Data::Broker.new(:name => 'hello', :broker_type => that)
      configuration and b.configuration = configuration
      b
    end

    it "should raise unless a real node object is given" do
      broker = {'test' => {'install.erb' => "# no real content here\n"}}
      with_brokers_in(paths.first => broker) do
        expect {
          b = Razor::BrokerType.find(name: 'test')
          b.install_script(self, broker_instance_for(b))
        }.to raise_error TypeError, /Razor::Data::Node/
      end
    end

    it "should produce the install script" do
      broker = {'test' => {'install.erb' => "# no real content here\n"}}
      with_brokers_in(paths.first => broker) do
        node   = Razor::Data::Node.new
        broker = Razor::BrokerType.find(name: 'test')
        script = broker.install_script(node, broker_instance_for(broker))
        script.should be_an_instance_of String
        script.should == "# no real content here\n"
      end
    end

    it "should pass the node to the install script template" do
      broker = {'test' => {'install.erb' => "<%= node.name %>"}}
      with_brokers_in(paths.first => broker) do
        node   = Fabricate(:node)
        broker = Razor::BrokerType.find(name: 'test')
        script = broker.install_script(node, broker_instance_for(broker))
        script.should == node.name
      end
    end

    it "should pass the log_url to the install script template" do
      broker = {'test' => {'install.erb' => "<%= log_url('test script ', :error) %>"}}
      with_brokers_in(paths.first => broker) do
        node   = Fabricate(:node)
        broker = Razor::BrokerType.find(name: 'test')
        script = broker.install_script(node, broker_instance_for(broker),
            'install', 'log_url' => 'http://localhost:8150/svc/log')
        script.should == 'http://localhost:8150/svc/log?msg=test+script+&severity=error'
      end
    end

    it "should pass the stage_done_url to the install script template" do
      broker = {'test' => {'install.erb' => "<%= stage_done_url %>"}}
      with_brokers_in(paths.first => broker) do
        node   = Fabricate(:node)
        broker = Razor::BrokerType.find(name: 'test')
        script = broker.install_script(node, broker_instance_for(broker),
            'install', 'stage_done_url' => 'stage is done')
        script.should == 'stage is done'
      end
    end

    it "should pass an immutable node to the template" do
      broker = {'test' => {'install.erb' => "<%= node.hw_info = ['serial=exploited!'] %>"}}
      with_brokers_in(paths.first => broker) do
        node = Fabricate(:node, :hw_info => [ "mac=12345678" ])
        expect {
          broker = Razor::BrokerType.find(name: 'test')
          script = broker.install_script(node, broker_instance_for(broker))
        }.to raise_error /frozen/
        node.hw_info.should == [ "mac=12345678" ]
      end
    end

    it "should pass an immutable broker configuration to the template" do
      broker = {'test' =>
        {'install.erb' => "<%= broker[:foo] = 'bar' %>"}}
      with_brokers_in(paths.first => broker) do
        node     = Razor::Data::Node.new
        broker   = Razor::BrokerType.find(name: 'test')
        config   = {'1' => 1, '2' => 2.0}
        instance = broker_instance_for(broker, config)
        instance.configuration.should == config

        expect {
          broker.install_script(node, instance)
        }.to raise_error /frozen/

        instance.configuration.should == config
      end
    end

    it "should evaluate in an immutable object context" do
      broker = {'test' => {'install.erb' => "<%= @foo = 'exploited!' %>"}}
      with_brokers_in(paths.first => broker) do
        node     = Razor::Data::Node.new
        broker   = Razor::BrokerType.find(name: 'test')
        instance = broker_instance_for(broker)

        expect {
          broker.install_script(node, instance)
        }.to raise_error RuntimeError, /frozen/
      end
    end
  end
end
