# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C536 Create Policy with Long Unicode name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/536"

name = long_unicode_string

step "using #{name.inspect} as the policy name"

reset_database

create_policy agents, policy_name: name do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies").output
  assert_match /#{Regexp.escape(name)}/, text
end
