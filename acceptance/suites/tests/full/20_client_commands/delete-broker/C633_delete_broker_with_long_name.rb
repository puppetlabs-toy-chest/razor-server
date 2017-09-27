# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'

confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete broker with long name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/633'

reset_database

razor agents, 'create-broker --name ' + ('a' * 250) + ' --broker-type noop' do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor brokers").output
  assert_match /#{'a' * 250}/, text
end

razor agents, 'delete-broker --name ' + ('a' * 250) do |agent|
  step "Verify that the broker is no longer defined on #{agent}"
  text = on(agent, "razor brokers").output
  refute_match /#{'a' * 250}/, text
end
