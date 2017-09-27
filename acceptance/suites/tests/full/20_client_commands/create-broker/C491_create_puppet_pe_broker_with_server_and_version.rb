# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C491	Create 'puppet-pe' Broker with server and version"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/491"

reset_database
json = {
  "name" => "pe-broker-test",
  "broker-type" => "puppet-pe",
  "configuration" =>{
    "server" => "puppet.example.com",
    "version" => "1.2.3"
  }
}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /pe-broker-test/, text
end

