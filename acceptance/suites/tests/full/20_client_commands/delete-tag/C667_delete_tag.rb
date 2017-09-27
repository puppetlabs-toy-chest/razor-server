# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/667'

reset_database

razor agents, 'create-tag --name puppet-test-tag --rule \'["=", ["fact", "processorcount"], "2"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /puppet-test-tag/, text
end

razor agents, 'delete-tag --name puppet-test-tag' do |agent|
  step "Verify that the tag is no longer defined on #{agent}"
  text = on(agent, "razor tags").output
  refute_match /puppet-test-tag/, text
end
