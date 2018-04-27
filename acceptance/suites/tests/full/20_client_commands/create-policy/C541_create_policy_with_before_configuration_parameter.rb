# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C541 Create Policy with before configuration parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/541"

reset_database

json = {
  "name" => "small",
  "rule" => ["=", ["fact", "processorcount"], "2"]
}

razor agents, 'create-tag', json

json = {
  "name" => "centos-6.4",
  "url"  => "http://provisioning.example.com/centos-6.4/x86_64/os/",
  "task" => "centos"
}

razor agents, 'create-repo', json

json = {
  "name"        => "noop",
  "broker-type" => "noop"
}

razor agents, 'create-broker', json

json = {
  "name"          => "centos-for-before",
  "repo"          => "centos-6.4",
  "task"          => "centos",
  "broker"        => "noop",
  "enabled"       => true,
  "hostname"      => "host${id}.example.com",
  "root-password" => "secret",
  "max-count"     => 20,
  "tags"          => ["small"]
}

razor agents, 'create-policy', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /centos-for-before/, text
end


json = {
  "name"          => "centos-with-before",
  "repo"          => "centos-6.4",
  "task"          => "centos",
  "broker"        => "noop",
  "enabled"       => true,
  "hostname"      => "host${id}.example.com",
  "root-password" => "secret",
  "max-count"     => 20,
  "tags"          => ["small"],
  "before"        => "centos-for-before"
}

razor agents, 'create-policy', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /centos-with-before/, text

  # Make sure they are ordered correctly...
  assert_match /centos-with-before.*centos-for-before/m, text
end
