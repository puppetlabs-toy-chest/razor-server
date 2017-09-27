# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'

confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete broker with long unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/633'

reset_database

name = long_unicode_string
json = {
    'name' => name,
    'broker-type' => 'noop'
}
razor agents, 'create-broker', json do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /#{Regexp.escape(name)}/, text
end

json = {
    'name' => name
}
razor agents, 'delete-broker', json do |agent|
  step "Verify that the broker is no longer defined on #{agent}"
  text = on(agent, "razor brokers").output
  refute_match /#{Regexp.escape(name)}/, text
end
