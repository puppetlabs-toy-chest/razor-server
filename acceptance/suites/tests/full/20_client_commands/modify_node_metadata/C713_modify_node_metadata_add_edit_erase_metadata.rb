# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify node metadata add/edit/erase metadata'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/713'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, 'modify-node-metadata --node ' + name + ' --update existing=value --update to-remove=old' do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /existing:\s+value/, text
  end
  razor agent, 'modify-node-metadata --node ' + name + ' --update new=new-value --update existing=changed --remove to-remove' do |agent|
    step "Verify that the metadata is added/edited/erased on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /new:\s+new-value/, text
    assert_match /existing:\s+changed/, text
    refute_match /to-remove:/, text
  end
end
