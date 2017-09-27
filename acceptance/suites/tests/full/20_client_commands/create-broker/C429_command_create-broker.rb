# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Command - "create-broker"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/429'

reset_database

json = {
  "name"          => "puppet-test-broker",
  "broker-type"   => "puppet",
  "configuration" => {
    "server"      => "puppet.example.org",
    "environment" => "production"
  }
}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-test-broker/, text
end

