# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Move policy after a different policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/747'

reset_database
create_policy agents, policy_name: 'puppet-test-policy'

razor agents, 'move-policy --name puppet-test-policy --after puppet-test-policy', nil, exit: 1 do |agent, output|
  assert_match /cannot move a policy relative to itself/, output
end
