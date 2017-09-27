# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag with blank rule parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/628'

reset_database

razor agents, 'create-tag --name puppet-test-tag --rule ""', nil, exit: 1 do |agent, output|
  assert_match /matcher must have at least one argument/, output
end