# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete node then reregister node'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/641'

reset_database

names = razor agents, 'register-node --installed true --hw-info \'{"net0": "abcdef"}\'' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name} --full").output
  assert_match /abcdef/, text

  razor agent, 'delete-node --name ' + name do |agent|
    step "Verify that node #{name} is no longer defined on #{agent}"
    text = on(agent, "razor nodes").output
    refute_match /#{name}/, text
  end

  razor agent, 'register-node --installed true --hw-info \'{"net0": "abcdef"}\'' do |agent, output|
    step "Verify that no error was raised on #{agent}"
    refute_match /[Ee]rror/, output
  end
end
