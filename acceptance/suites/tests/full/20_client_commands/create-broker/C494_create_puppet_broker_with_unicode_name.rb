# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C494	Create 'puppet' Broker with Unicode Name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/496"

name = unicode_string

reset_database
json = {
  "name" => "#{name}",
  "broker-type" => "puppet"
}

razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /#{Regexp.escape(name)}/, text
end

