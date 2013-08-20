require 'pathname'

Fabricator(:broker, :class_name => Razor::Data::Broker) do
  name   { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  # This is fixed, because we need something on disk to back it!
  broker_type do
    path = Pathname(__FILE__).dirname + '..' + 'fixtures' + 'brokers' + 'test.broker'
    Razor::BrokerType.new(path)
  end
end


Fabricator(:image, :class_name => Razor::Data::Image) do
  name      { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  image_url 'file:///dev/null'
end


Fabricator(:policy, :class_name => Razor::Data::Policy) do
  name             { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  enabled          true
  installer_name   'some_os'
  hostname_pattern 'host${id}.example.org'
  root_password    { Faker::Lorem.word }
  line_number      { Fabricate.sequence(:razor_data_policy_line_number, 100) }

  image
  broker
end


Fabricator(:node, :class_name => Razor::Data::Node) do
  # not strictly a legal MAC, but the shape is correct.  (eg: could be a
  # broadcast MAC, or some other invalid value.)
  hw_id { 6.times.map { Random.rand(256).to_s(16) }.join }
end
