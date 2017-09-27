# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag with blank name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/625'

reset_database

razor agents, 'create-tag --name "" --rule \'["=", ["fact", "processorcount"], "2"]\'', nil, exit: 1 do |agent, output|
  assert_match /name must be at least 1 characters in length, but is only 0 characters long/, output
end