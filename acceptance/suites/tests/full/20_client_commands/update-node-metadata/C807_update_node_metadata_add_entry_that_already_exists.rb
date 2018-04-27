# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Update node metadata add entry that already exists'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/807'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, 'update-node-metadata --node ' + name + ' --key key --value value' do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+\n\s+key:\s+value/, text
  end

  razor agent, 'update-node-metadata --node ' + name + ' --key key --value new-value --no-replace', nil, exit: 1 do |agent, text|
    step "Verify that an error is thrown on #{agent}"
    assert_match /409 Conflict/, text
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+\n\s+key:\s+value/, text
  end
end