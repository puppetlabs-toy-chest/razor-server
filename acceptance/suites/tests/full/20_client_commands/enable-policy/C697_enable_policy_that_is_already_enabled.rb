# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Enable policy that is already enabled'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/696'

reset_database

result = create_policy agents, policy_name: 'a' * 250
name = result[:policy][:name]

agents.each do |agent|
  step "Verify that the broker is enabled on #{agent}"
  text = on(agent, "razor policies #{name}").output
  assert_match /enabled:\s+true/, text
end

razor agents, 'enable-policy --name ' + name do |agent|
  step "Verify that the policy is still enabled on #{agent}"
  text = on(agent, "razor policies #{name}").output
  assert_match /enabled:\s+true/, text
end
