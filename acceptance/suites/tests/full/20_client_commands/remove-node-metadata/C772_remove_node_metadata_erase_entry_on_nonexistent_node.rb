# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove node metadata erase entry on non-existent node'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/772'

reset_database

razor agents, "remove-node-metadata --node does-not-exist --key key", nil, exit: 1 do |agent, output|
  assert_match /node must be the name of an existing node, but is 'does-not-exist'/, output
end
