# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C481	Create 'noop' Broker with Unicode Name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/481"

reset_database
name = unicode_string
json = {"name" => name, "broker-type" => "noop"}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /#{Regexp.escape(name)}/, text
end

