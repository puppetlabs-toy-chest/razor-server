# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Update node metadata on nonexistent node'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/808'

reset_database

razor agents, 'update-node-metadata --node does-not-exist --key key --value value', nil, exit: 1 do |agent, output|
  assert_match /node must be the name of an existing node, but is 'does-not-exist'/, output
end