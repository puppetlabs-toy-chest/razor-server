# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete tag with non-existent tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/677'

reset_database

razor agents, 'delete-tag --name does-not-exist' do |agent, output|
  assert_match /No change. Tag does-not-exist does not exist./, output
end
