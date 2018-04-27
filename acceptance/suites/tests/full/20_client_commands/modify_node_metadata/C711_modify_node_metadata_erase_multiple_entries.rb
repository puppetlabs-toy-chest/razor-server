# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify node metadata erase multiple entries'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/711'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, 'modify-node-metadata --node ' + name + ' --update key=value --update other-key=other-value' do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /key:\s+value/, text
    assert_match /other-key:\s+other-value/, text
  end
  razor agent, 'modify-node-metadata --node ' + name + ' --remove key --remove other-key' do |agent|
    step "Verify that the metadata is erased on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    refute_match /key:\s+value/, text
    refute_match /other-key:\s+other-value/, text
  end
end
