# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C502	Create 'puppet' Broker with environment and server"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/502"

reset_database
json = {
  "name" => "puppet-broker-test",
  "broker-type" => "puppet",
  "configuration" =>{
    "environment" => "testing",
    "server" => "puppet.example.com"
  }
}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-broker-test/, text
end

