# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Command - "brokers"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/443'

reset_database

json = {
  "name"          => "puppet-test-broker",
  "broker-type"   => "puppet",
  "configuration" => {
    "server"      => "puppet.example.org",
    "environment" => "production"
  }
}

agents.each do |agent|
  step "Test empty query results on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /There are no items for this query./, text
end

razor agents, 'create-broker', json do |agent|
  step "Test single entry in query results"
  text = on(agent, "razor brokers").output
  assert_match /puppet-test-broker/, text
end
