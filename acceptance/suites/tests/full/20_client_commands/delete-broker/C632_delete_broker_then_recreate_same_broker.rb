# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'

confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete broker then recreate same broker'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/632'

reset_database

razor agents, 'create-broker --name puppet-test-broker --broker-type noop' do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-test-broker/, text
end

razor agents, 'delete-broker --name puppet-test-broker' do |agent|
  step "Verify that the broker is no longer defined on #{agent}"
  text = on(agent, "razor brokers").output
  refute_match /puppet-test-broker/, text
end

razor agents, 'create-broker --name puppet-test-broker --broker-type noop' do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /puppet-test-broker/, text
end
