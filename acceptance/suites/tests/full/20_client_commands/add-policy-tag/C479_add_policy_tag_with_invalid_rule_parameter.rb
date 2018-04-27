# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Add policy tag with invalid rule parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/479'

reset_database

results = create_policy agents
policy_name = results[:policy][:name]

razor agents, "add-policy-tag --name #{policy_name} --tag puppet-test-tag --rule " + '\'["so invalid"\'', nil, exit: 1 do | agent, output |
  assert_match /matcher must have at least one argument/, output
end