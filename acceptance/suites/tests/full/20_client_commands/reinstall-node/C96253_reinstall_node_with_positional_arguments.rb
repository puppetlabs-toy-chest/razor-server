# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Reinstall node with positional arguments'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/765'

reset_database

razor agents, 'register-node --installed false --hw-info \'{"net0": "abcdef"}\'' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name} --full").output
  assert_match /abcdef/, text

  razor agent, 'reinstall-node ' + name, nil do |agent, output|
    assert_match /no changes; node #{name} was neither bound nor installed/, output
  end
end

