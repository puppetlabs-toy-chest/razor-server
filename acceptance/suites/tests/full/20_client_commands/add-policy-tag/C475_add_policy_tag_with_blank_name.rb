# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Add policy tag with blank name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/475'

reset_database

tag_name = 'puppet-test-tag'

razor agents, "add-policy-tag --name '' --tag #{tag_name}", nil, exit: 1 do |agent, output|
  assert_match /name must be the name of an existing policy, but is ''/, output
end
