# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C538 Create Policy with max-count configuration parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/538"

reset_database

create_policy agents, policy_max_count: 20150 do |agent, _, hash|
  step "Verify that the policy is defined on #{agent}"
  text = on(agent, "razor policies #{hash[:policy][:name]}").output
  assert_match /20150/, text
end
