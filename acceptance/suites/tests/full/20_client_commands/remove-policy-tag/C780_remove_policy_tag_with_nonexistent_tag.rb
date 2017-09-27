# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove policy tag with nonexistent tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/780'

reset_database

results = create_policy agents

razor agents, "remove-policy-tag --name #{results[:policy][:name]} --tag does-not-exist" do |agent, output|
  assert_match /Tag does-not-exist was not on policy #{results[:policy][:name]}/, output
end