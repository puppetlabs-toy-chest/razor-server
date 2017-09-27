# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Disable policy with blank name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/685'

reset_database

razor agents, 'disable-policy --name ""', nil, exit: 1 do |agent, output|
  assert_match /name must be the name of an existing policy, but is ''/, output
end
