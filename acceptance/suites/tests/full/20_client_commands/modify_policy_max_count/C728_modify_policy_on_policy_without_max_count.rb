# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "Modify policy max count on policy without max count"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/728"

reset_database
result = create_policy agents, policy_max_count: nil

agents.each do |agent|
  text = on(agent, "razor policies puppet-test-policy").output
  assert_match /max_count:\s+nil/, text
end

razor agents, "modify-policy-max-count --name #{result[:policy][:name]} --max-count 6" do |agent|
  step "Verify that the count was increased on #{agent}"
  text = on(agent, "razor policies #{result[:policy][:name]}").output
  assert_match /max_count:\s+6/, text
end
