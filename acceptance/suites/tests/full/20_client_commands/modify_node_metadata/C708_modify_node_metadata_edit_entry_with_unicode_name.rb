# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify node metadata edit entry with unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/708'

reset_database

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  node_name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{node_name}").output
  assert_match /name: /, text
  key = long_unicode_string
  value = long_unicode_string
  new_value = long_unicode_string

  json = {
      'node' => node_name,
      'update' => {key => value}
  }
  razor agent, 'modify-node-metadata', json do |agent|
    step "Verify that the metadata for node #{node_name} is defined on #{agent}"
    text = on(agent, "razor nodes #{node_name}").output
    assert_match /metadata:\s+\n\s+#{Regexp.escape(key)}:\s+#{Regexp.escape(value)}/, text
  end
  json = {
      'node' => node_name,
      'update' => {key => new_value}
  }
  razor agent, 'modify-node-metadata', json do |agent|
    step "Verify that the metadata for node #{node_name} is edited on #{agent}"
    text = on(agent, "razor nodes #{node_name}").output
    assert_match /metadata:\s+\n\s+#{Regexp.escape(key)}:\s+#{Regexp.escape(new_value)}/, text
  end
end
