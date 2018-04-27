# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag with rule configuration using "metadata" match expression'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/613'

reset_database

razor agents, 'create-tag --name puppet-test-tag --rule \'["=", ["metadata", "key"], "value"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /puppet-test-tag/, text
end