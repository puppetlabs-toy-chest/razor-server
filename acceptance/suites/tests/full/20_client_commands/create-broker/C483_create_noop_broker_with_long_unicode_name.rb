# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C483	Create 'noop' Broker with Long Unicode Name (250 characters)"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/483"

name = long_unicode_string

step "using #{name.inspect} as the broker name"

reset_database
json = {"name" => "#{name}", "broker-type" => "noop"}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /#{Regexp.escape(name)}/, text
end

