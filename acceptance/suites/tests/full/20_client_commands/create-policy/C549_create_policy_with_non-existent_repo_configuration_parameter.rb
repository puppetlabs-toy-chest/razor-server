# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C549 Create Policy with non-existent repo configuration parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/549"

reset_database agents

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
  "name"          => "centos-for-small",
  "task"          => "centos",
  "broker"        => "noop",
  "enabled"       => true,
  "hostname"      => "host${id}.example.com",
  "root-password" => "secret",
  "max-count"     => 20,
  "tags"          => ["small"]
}

razor agents, 'create-policy', json, exit: 1 do |agent, text|
  assert_match /422 Unprocessable Entity/, text
  assert_match /repo is a required attribute, but it is not present/, text
end
