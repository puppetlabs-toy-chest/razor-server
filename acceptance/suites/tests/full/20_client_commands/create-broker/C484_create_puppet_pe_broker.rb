# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C484	Create 'puppet-pe' Broker"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/484"

reset_database

json = {"name" => "pe-broker-test", "broker-type" => "puppet-pe"}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /pe-broker-test/, text
end

