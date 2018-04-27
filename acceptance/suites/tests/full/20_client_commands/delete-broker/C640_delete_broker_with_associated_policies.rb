# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'

confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete broker with associated policies'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/640'

reset_database

step 'Set up dependencies'
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
    "name"        => "puppet-test-broker",
    "broker-type" => "noop"
}
json = {
    "name"          => "centos-for-small",
    "repo"          => "centos-6.4",
    "task"          => "centos",
    "broker"        => "puppet-test-broker",
    "enabled"       => true,
    "hostname"      => "host${id}.example.com",
    "root-password" => "secret",
    "max-count"     => 20,
    "tags"          => ["small"]
}

razor agents, 'create-policy', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies").output
  assert_match /centos-for-small/, text
end

razor agents, 'delete-broker --name puppet-test-broker', nil, exit: 1 do |agent, output|
  assert_match /Broker puppet-test-broker is still used by policies/, output
end
