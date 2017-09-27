# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Move policy after non-existent policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/749'

reset_database
create_policy agents, policy_name: 'puppet-test-policy'

razor agents, 'move-policy --name puppet-test-policy --after does-not-exist', nil, exit: 1 do |agent, output|
  assert_match /after must be the name of an existing policy, but is 'does-not-exist'/, output
end
