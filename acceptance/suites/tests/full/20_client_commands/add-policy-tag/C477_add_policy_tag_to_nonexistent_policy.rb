# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Add policy tag to nonexistent policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/477'

reset_database

razor agents, 'add-policy-tag --name does-not-exist --tag puppet-test-tag --rule \'["and", true, false]\'', nil, exit: 1 do | agent, output |
  assert_match /name must be the name of an existing policy, but is 'does-not-exist'/, output
end