# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete node with non-existent node'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/648'

reset_database

razor agents, 'delete-node --name does-not-exist' do |agent, output|
  assert_match /no changes; node does-not-exist does not exist/, output
end
