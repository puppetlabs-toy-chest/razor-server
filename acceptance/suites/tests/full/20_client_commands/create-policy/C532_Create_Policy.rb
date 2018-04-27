# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C532 Create Policy"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/532"

reset_database
name = 'centos-for-small'
create_policy agents, policy_name: name do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies").output
  assert_match /centos-for-small/, text
end
