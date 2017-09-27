# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete repo without name parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/665'

reset_database

razor agents, 'delete-repo', nil, exit: 1 do |agent, output|
  assert_match /No arguments for command/, output
end
