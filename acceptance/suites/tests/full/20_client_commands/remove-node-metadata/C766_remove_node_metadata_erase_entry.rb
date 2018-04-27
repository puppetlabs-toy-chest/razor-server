# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove node metadata erase entry'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/766'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, 'modify-node-metadata --node ' + name + ' --update key=value' do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+\n\s+key:\s+value/, text
  end

  razor agent, 'remove-node-metadata --node ' + name + ' --key key' do |agent|
    step "Verify that the metadata is no longer defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+---/, text
  end
end
