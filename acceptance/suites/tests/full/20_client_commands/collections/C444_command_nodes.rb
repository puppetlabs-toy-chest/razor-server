# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Command - "nodes"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/444'

reset_database

agents.each do |agent|
  step "Test empty query results on #{agent}"
  text = on(agent, "razor nodes").output
  assert_match /There are no items for this query./, text
end

razor agents, 'register-node --installed true --hw-info \'{"net0": "abcdef"}\'' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Test single query result on #{agent}"
  text = on(agent, "razor nodes #{name} --full").output
  assert_match /abcdef/, text
end
