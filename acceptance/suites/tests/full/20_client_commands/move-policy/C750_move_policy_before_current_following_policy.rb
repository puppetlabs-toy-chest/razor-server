# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Move policy before current following policy (no order change)'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/750'

reset_database
create_policy agents, policy_name: 'before-policy'
create_policy agents, policy_name: 'after-policy', just_policy: true

agents.each do |agent|
  step "Verify that 'before-policy' is originally defined before 'after-policy' on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /before-policy.+after-policy/m, text
end

razor agents, 'move-policy --name before-policy --before after-policy' do |agent, output|
  refute_match /[Ee]rror/, output
  step "Verify that 'before-policy' is still defined after 'after-policy' on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /before-policy.+after-policy/m, text
end
