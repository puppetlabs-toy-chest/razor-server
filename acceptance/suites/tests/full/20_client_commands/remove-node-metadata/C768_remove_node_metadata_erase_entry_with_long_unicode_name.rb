# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove node metadata erase entry with long unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/768'

reset_database
key_name = long_unicode_string
value = long_unicode_string

razor agents, 'register-node --installed true --hw-info net0=abcdef' do |agent, output|
  name = /name:\s+(?<name>.+)/.match(output)[:name]
  step "Verify that the node is defined on #{agent}"
  text = on(agent, "razor nodes #{name}").output
  assert_match /name: /, text

  json = {
      'node' => name,
      'update' => {key_name => value}
  }
  razor agent, "modify-node-metadata", json do |agent|
    step "Verify that the metadata is defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+\n\s+#{Regexp.escape(key_name)}:\s+#{Regexp.escape(value)}/, text
  end

  json = {
      'node' => name,
      'key' => key_name
  }
  razor agent, 'remove-node-metadata', json do |agent|
    step "Verify that the metadata is no longer defined on #{agent}"
    text = on(agent, "razor nodes #{name}").output
    assert_match /metadata:\s+---/, text
  end
end
