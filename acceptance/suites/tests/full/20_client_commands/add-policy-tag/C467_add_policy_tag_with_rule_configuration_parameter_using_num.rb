# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Add policy tag with rule configuration parameter using "num"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/467'

reset_database

tag_name = 'puppet-test-tag'

results = create_policy agents
policy_name = results[:policy][:name]

razor agents, "add-policy-tag --name #{policy_name} --tag #{tag_name} --rule " + '\'["=", ["num", "123"], 123]\'' do |agent|
  step "Verify that the tag is associated with policy on #{agent}"
  text = on(agent, "razor policies #{policy_name}").output
  assert_match /#{tag_name}/, text
end
