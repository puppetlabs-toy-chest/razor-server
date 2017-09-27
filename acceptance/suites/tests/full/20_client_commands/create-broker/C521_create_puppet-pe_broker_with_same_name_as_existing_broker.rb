# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C521	Create 'puppet-pe' Broker with Same Name as Existing Broker"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/521"

reset_database

json1 = {"name" => "puppet-broker-test", "broker-type" => "puppet"}
json2 = {"name" => "puppet-broker-test", "broker-type" => "puppet-pe"}

razor agents, 'create-broker', json1 do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-broker-test/, text
end

razor agents, 'create-broker', json2, exit: 1 do |agent, text|
  assert_match /The broker puppet-broker-test already exists, and the broker_type fields do not match/, text
end

