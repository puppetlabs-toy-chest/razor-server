# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove node metadata erase entry with blank key'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/771'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, "remove-node-metadata --node #{name} --key ''", nil, exit: 1 do |agent, output|
    assert_match /key must be at least 1 characters in length, but is only 0 characters long/, output
  end
end
