# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Force delete tag with associated policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/672'

reset_database

razor agents, 'create-tag --name puppet-test-tag --rule \'["=", ["fact", "processorcount"], "2"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /puppet-test-tag/, text
end

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
    "name"          => "puppet-test-policy",
    "repo"          => "centos-6.4",
    "task"          => "centos",
    "broker"        => "noop",
    "enabled"       => true,
    "hostname"      => "host${id}.example.com",
    "root-password" => "secret",
    "max-count"     => 20,
    "tags"          => ["puppet-test-tag"]
}

razor agents, 'create-policy', json do |agent|
  step "Verify that the policy is defined on #{agent}"
  text = on(agent, "razor policies").output
  assert_match /puppet-test-policy/, text
end

razor agents, 'delete-tag --name puppet-test-tag --force' do |agent|
  step "Verify that the tag is no longer defined on #{agent}"
  text = on(agent, "razor tags").output
  refute_match /puppet-test-tag/, text
end
