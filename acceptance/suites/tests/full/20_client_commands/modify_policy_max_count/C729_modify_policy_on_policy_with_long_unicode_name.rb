# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "Modify policy max count on policy with long unicode name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/729"

reset_database
name = long_unicode_string

result = create_policy agents, policy_name: name, policy_max_count: 5

agents.each do |agent|
  text = on(agent, "razor policies '#{name}'").output
  assert_match /max_count:\s+5/, text
end

json = {
    'name' => name,
    'max-count' => 6
}
razor agents, 'modify-policy-max-count', json do |agent|
  step "Verify that the count was increased on #{agent}"
  text = on(agent, "razor policies '#{name}'").output
  assert_match /max_count:\s+6/, text
end
