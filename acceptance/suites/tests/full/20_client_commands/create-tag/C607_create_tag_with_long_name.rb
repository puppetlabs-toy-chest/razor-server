# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag with long name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/606'

reset_database

razor agents, 'create-tag --name ' + ('t' * 250) + ' --rule \'["=", ["fact", "processorcount"], "2"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /#{'t' * 250}/, text
end