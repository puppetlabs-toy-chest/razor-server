# -*- encoding: utf-8 -*-
require 'pathname'

def random_version
  3.times.map {|n| Random.rand(20).to_s }.join('.')
end

def random_mac
  # not strictly a legal MAC, but the shape is correct.  (eg: could be a
  # broadcast MAC, or some other invalid value.)
  6.times.map { Random.rand(256).to_s(16).downcase }.join("-")
end

ASSET_CHARS=('A'..'Z').to_a + ('0'..'9').to_a
def random_asset
  ASSET_CHARS.sample(6).join.downcase
end

Fabricator(:broker, :class_name => Razor::Data::Broker) do
  name   { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  # This is fixed, because we need something on disk to back it!
  broker_type do
    path = Pathname(__FILE__).dirname + '..' + 'fixtures' + 'brokers' + 'test.broker'
    Razor::BrokerType.new(path)
  end
end

Fabricator(:broker_with_policy, from: :broker) do
  after_build do |broker, _|
    policy = Fabricate(:policy)
    broker.save
    policy.broker = broker
    policy.save
  end
end

Fabricator(:repo, :class_name => Razor::Data::Repo) do
  name      { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  iso_url   'file:///dev/null'
  task_name { Fabricate(:task).name }
end


Fabricator(:task, :class_name => Razor::Data::Task) do
  name          { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  os            { Faker::Commerce.product_name }
  os_version    { random_version }
  description   { Faker::Lorem.sentence }
  boot_seq      {{'default' => 'boot_local'}}
end

Fabricator(:tag, :class_name => Razor::Data::Tag) do
  name { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  rule { ["=", "1", "1"] }
end

Fabricator(:policy, :class_name => Razor::Data::Policy) do
  name             { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  enabled          true
  hostname_pattern 'host${id}.example.org'
  root_password    { Faker::Internet.password }

  repo
  broker
end

Fabricator(:policy_with_tag, from: :policy) do
  tags(count: 3) { Fabricate(:tag) }
end

Fabricator(:node, :class_name => Razor::Data::Node) do
  name    "placeholder"
  hw_info { [ "mac=#{random_mac}", "asset=#{random_asset}" ] }

  after_save do |node, _|
    node.set(name: "node#{node[:id]}").save
  end
end

Fabricator(:node_with_ipmi, from: :node) do
  ipmi_hostname { Faker::Internet.domain_name }
end

Fabricator(:node_with_facts, from: :node) do
  hw_info { [ "mac=#{random_mac}", "asset=#{random_asset}" ] }
  facts   { { "f1" => "a" } }
end

Fabricator(:node_with_metadata, from: :node) do
  hw_info  { [ "mac=#{random_mac}", "asset=#{random_asset}" ] }
  metadata { { "m1" => "a" } }
end

Fabricator(:installed_node, from: :node) do
  installed "+test"
  installed_at { Time.now }
end

Fabricator(:bound_node, from: :node) do
  policy

  facts do
    data = {}
    20.times do
      data[Faker::Lorem.word] = case Random.rand(4)
                                  when 0 then Faker::Lorem.word
                                  when 1 then Random.rand(2**34).to_s
                                  when 2 then random_version
                                  when 3 then 'true'
                                  else raise "unexpected random number!"
                                end
    end
    data
  end

  metadata do
    data = { }
    # 25% of nodes will have an IP generated
    data["ip"] = Faker::Internet.ip_v4_address if Random.rand(4) == 3
    20.times do
      data[Faker::Lorem.word] = case Random.rand(4)
                                  when 0 then Faker::Lorem.word
                                  when 1 then Random.rand(2**34).to_s
                                  when 2 then random_version
                                  when 3 then 'true'
                                  else raise "unexpected random number!"
                                end
    end
    data
  end

  boot_count { Random.rand(10) }

  # normally the node would be created before binding, so we always have an ID
  # assigned; while we are faking one up that doesn't hold, so this helps us
  # skip past the database constraint and the after_save hook fixes everything
  # up before the end user gets their hands on the data.
  hostname   'strictly.temporary.org'

  after_build do |node, _|
    # @todo danielp 2013-08-19: this seems to highlight some data duplication
    # that, frankly, doesn't seem like a good thing to me.
    node.root_password = node.policy.root_password
  end

  after_save do |node, _|
    node.hostname = node.policy.hostname_pattern.gsub('${id}', node.id.to_s)
    node.save
  end
end

Fabricator(:command) do
  command 'do-something'
  status  'pending'
end

Fabricator(:hook, :class_name => Razor::Data::Hook) do
  name      { Faker::Commerce.product_name + " #{Fabricate.sequence}" }
  # This is fixed, because we need something on disk to back it!
  hook_type do
    path = Pathname(__FILE__).dirname + '..' + 'fixtures' + 'hooks' + 'test.hook'
    Razor::HookType.new(path)
  end
end

Fabricator(:event, :class_name => Razor::Data::Event) do
  entry do
    {msg: Faker::Commerce.product_name}
  end
  # hook_id { Fabricate(:hook).id }
  node_id { Fabricate(:bound_node).id }
  policy_id { Fabricate(:policy).id }
end