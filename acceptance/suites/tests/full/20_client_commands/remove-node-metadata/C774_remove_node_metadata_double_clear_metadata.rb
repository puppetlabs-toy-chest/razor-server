# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove node metadata double clear metadata'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/774'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  razor agent, "modify-node-metadata --node #{name} --update key=value --update otherkey=othervalue" do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /key:\s+value/, text
    assert_match /otherkey:\s+othervalue/, text
  end

  razor agent, "remove-node-metadata --node #{name} --all" do |agent|
    step "Verify that the metadata is no longer defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+---/, text
  end

  razor agent, "remove-node-metadata --node #{name} --all" do |agent|
    step "Verify that the metadata is still not defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+---/, text
  end
end
