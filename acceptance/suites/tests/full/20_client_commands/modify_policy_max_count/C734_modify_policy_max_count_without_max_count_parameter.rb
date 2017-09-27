# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify policy max count without max count parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/734'

reset_database

results = create_policy agents

razor agents, "modify-policy-max-count --name #{results[:policy][:name]}", nil, exit:1 do |agent, output|
  assert_match /the command requires one out of the max_count, no_max_count attributes to be supplied/, output
end
