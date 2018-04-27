# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create tag with same name as existing tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/624'

reset_database

razor agents, 'create-tag --name puppet-test-tag --rule \'["=", ["fact", "processorcount"], "2"]\'' do |agent, output|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /puppet-test-tag/, text
end
razor agents, 'create-tag --name puppet-test-tag --rule \'["=", ["fact", "some-other-fact"], "2"]\'', nil, exit: 1 do |agent, output|
  # @todo smcclellan 2014-03-30: This error will change when idempotency is preserved for this command.
  assert_match /The tag puppet-test-tag already exists, and the matcher fields do not match/, output
end