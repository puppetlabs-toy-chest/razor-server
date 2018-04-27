# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C564 Create Policy with blank max_count parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/564"

reset_database

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
  "task"          => "centos",
  "broker"        => "noop",
  "enabled"       => true,
  "hostname"      => "host${id}.example.com",
  "root-password" => "secret",
  "max-count"     => '',
  "tags"          => ["small"]
}

razor agents, 'create-policy', json, exit: 1 do |agent, text|
  assert_match /422 Unprocessable Entity/, text
  assert_match /max_count should be a number, but was actually a string/, text
end
