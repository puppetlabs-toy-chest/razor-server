require 'spec_helper'

describe Razor::Data::Broker do
  around :each do |test|
    Dir.mktmpdir do |dir|
      Razor.config['broker_path'] = dir

      # Create the stub broker, ready to go for testing.
      broker = Pathname(dir) + 'test.broker'
      broker.mkpath
      set_broker_file('install.erb' => "# no actual content\n")

      test.run
    end
  end

  def set_broker_file(file)
    root = Pathname(Razor.config.broker_paths.first)
    file.each do |name, content|
      file = (root + 'test.broker' + name)
      if content then
        file.open('w'){|f| f.print content }
      else
        file.unlink
      end
    end
  end

  # Deliberately not memorizing the result of this; do that yourself.
  def broker
    Razor::BrokerType.find('test')
  end

  describe "name" do
    it "name is case-insensitively unique" do
      Razor::Data::Broker.new(:name => 'hello', :broker_type => broker).save
      expect {
        Razor::Data::Broker.new(:name => 'HeLlO', :broker_type => broker).save
      }.to raise_error Sequel::UniqueConstraintViolation
    end

    it "does not accept newlines" do
      Razor::Data::Broker.new(:name => "hello\nworld", :broker_type => broker).
        should_not be_valid
    end
  end

  describe "broker" do
    it "should accept a Razor::BrokerType instance" do
      # If this doesn't raise any exceptions, we win. :)
      Razor::Data::Broker.new(:name => 'hello', :broker_type => broker).save
    end

    it "should have a Razor::BrokerType instance after loaded" do
      Razor::Data::Broker.new(:name => 'hello', :broker_type => broker).save
      loaded = Razor::Data::Broker[:name => 'hello'].broker_type
      loaded.should be_an_instance_of Razor::BrokerType
      loaded.name.should == broker.name
    end

    it "should not accept a string" do
      expect {
        Razor::Data::Broker.new(:name => 'hello', :broker_type => 'test').save
      }.to raise_error Sequel::ValidationFailed, "broker_type 'test' is not valid"
    end
  end

  describe "configuration" do
    it "should default to an empty hash" do
      instance = Razor::Data::Broker.new(:name => 'hello', :broker_type => 'test')
      instance.configuration.should == {}
    end

    it "should accept and save an empty hash" do
      Razor::Data::Broker.new(
        :name          => 'hello',
        :broker_type   => broker,
        :configuration => {}
      ).save
    end

    it "should round-trip a rich configuration" do
      config = {"one" => 1, "two" => 2.0, "three" => ['a', {'b'=>'b'}, ['c']]}
      Razor::Data::Broker.new(
        :name          => 'hello',
        :broker_type   => broker,
        :configuration => config
      ).save

      Razor::Data::Broker[:name => 'hello'].configuration.should == config
    end
  end
end
