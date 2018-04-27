# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Add policy tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/453'

reset_database

tag_name = 'puppet-test-tag'

razor agents, 'create-tag --name ' + tag_name + ' --rule \'["=", ["fact", "processorcount"], "2"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /#{tag_name}/, text
end

results = create_policy agents
policy_name = results[:policy][:name]

agents.each do |agent|
  step "Verify that the tag is not associated with policy on #{agent}"
  text = on(agent, "razor policies #{policy_name}").output
  refute_match /#{tag_name}/, text
end

razor agents, "add-policy-tag --name #{policy_name} --tag #{tag_name}" do |agent|
  step "Verify that the tag is associated with policy on #{agent}"
  text = on(agent, "razor policies #{policy_name}").output
  assert_match /#{tag_name}/, text
end
