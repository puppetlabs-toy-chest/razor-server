# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Move policy after a different policy with a long unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/743'

reset_database
first_result = create_policy agents, policy_name: long_unicode_string
first_name = first_result[:policy][:name]
second_result = create_policy agents, policy_name: long_unicode_string, just_policy: true
second_name = second_result[:policy][:name]

agents.each do |agent|
  step "Verify that #{first_name} is originally defined before #{second_name} on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /#{Regexp.escape(first_name)}.+#{Regexp.escape(second_name)}/m, text
end

json = {
    'name' => first_name,
    'after' => second_name
}
razor agents, 'move-policy', json do |agent|
  step "Verify that '#{first_name}' is now defined after '#{second_name}' on #{agent}"
  text = on(agent, "razor policies --full").output
  assert_match /#{Regexp.escape(second_name)}.+#{Regexp.escape(first_name)}/m, text
end
