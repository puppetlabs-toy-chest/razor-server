# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag without name parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/626'

reset_database

razor agents, 'create-tag --rule \'["=", ["fact", "processorcount"], "2"]\'', nil, exit: 1 do |agent, output|
  assert_match /name is a required attribute, but it is not present/, output
end