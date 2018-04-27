# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Command - "create-broker" with positional arguments'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/429'

reset_database

razor agents, 'create-broker puppet-test-broker puppet' do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-test-broker/, text
end

