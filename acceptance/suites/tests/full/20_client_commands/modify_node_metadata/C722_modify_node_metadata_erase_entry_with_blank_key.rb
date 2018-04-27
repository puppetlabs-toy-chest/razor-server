# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify node metadata erase entry with blank key'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/722'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  json = {
      'node' => name,
      'remove' => ['']
  }
  razor agent, 'modify-node-metadata', json do |agent, output|
    refute_match /[Ee]rror/, output
  end
end