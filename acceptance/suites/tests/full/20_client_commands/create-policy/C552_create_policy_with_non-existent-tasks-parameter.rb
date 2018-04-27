# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C552 Create Policy with non-existent tasks configuration parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/552"

reset_database agents

razor agents, 'create-tag', {
  "name" => "small",
  "rule" => ["=", ["fact", "processorcount"], "2"]
}

razor agents, 'create-repo', {
  "name" => "centos-6.4",
  "url"  => "http://provisioning.example.com/centos-6.4/x86_64/os/",
  "task" => "centos"
}

razor agents, 'create-broker', {
  "name"        => "noop",
  "broker-type" => "noop"
}


json = {
  "name"          => "centos-for-small",
  "repo"          => "centos-6.4",
  "task"          => "explode",
  "broker"        => "noop",
  "enabled"       => true,
  "hostname"      => "host${id}.example.com",
  "root-password" => "secret",
  "max-count"     => 20,
  "tags"          => ["small"]
}

razor agents, 'create-policy', json, exit: 1 do |agent, text|
  assert_match /400 Bad Request/, text
  assert_match /task task 'explode' does not exist/, text
end
