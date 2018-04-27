# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Disable policy with nonexistent policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/688'

reset_database

razor agents, 'disable-policy --name does-not-exist', nil, exit: 1 do |agent, output|
  assert_match /name must be the name of an existing policy, but is 'does-not-exist'/, output
end
