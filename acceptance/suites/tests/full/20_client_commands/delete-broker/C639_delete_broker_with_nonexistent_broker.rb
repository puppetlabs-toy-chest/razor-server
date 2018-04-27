# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'

confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete broker with non-existent broker'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/639'

reset_database

razor agents, 'delete-broker --name does-not-exist' do |agent, output|
  assert_match /no changes; broker does-not-exist does not exist/, output
end
