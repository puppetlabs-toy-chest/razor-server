# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Reboot node that lacks IPMI credentials'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/757'

reset_database

razor agents, 'register-node --installed true --hw-info \'{"net0": "abcdef"}\'' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name} --full").output
  assert_match /abcdef/, text

  razor agent, 'reboot-node --name ' + name, nil, exit: 1 do |agent, output|
    assert_match /node #{name} does not have IPMI credentials set/, output
  end
end

