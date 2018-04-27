# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete policy with non-existent policy'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/656'

reset_database

razor agents, 'delete-policy --name does-not-exist' do |agent, output|
  assert_match /no changes; policy does-not-exist does not exist/, output
end
