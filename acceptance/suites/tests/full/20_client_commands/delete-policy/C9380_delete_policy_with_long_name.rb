# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete policy with long name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/9380'

reset_database

data = "abcdefABCDEF12345"
name = (1..250).map { data[rand(data.length)] }.join
create_policy agents, policy_name: name

razor agents, 'delete-policy --name ' + name do |agent|
  step "Verify that the policy is no longer defined on #{agent}"
  text = on(agent, "razor policies").output
  refute_match /#{name}/, text
end
