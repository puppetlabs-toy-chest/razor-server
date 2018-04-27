# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C535 Create Policy with Long name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/535"

data = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map(&:to_a).flatten
name = (1..250).map { data[rand(data.length)] }.join

step "using #{name.inspect} as the broker name"

reset_database
create_policy agents, policy_name: name do |agent|
  step "Verify that the broker is defined on #{agent}"
  text = on(agent, "razor policies").output
  assert_match /#{name}/, text
end
