# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Modify policy max count with negative max count parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/735'

reset_database

results = create_policy agents

razor agents, "modify-policy-max-count --name #{results[:policy][:name]} --max-count -10", nil, exit:1 do |agent, output|
  assert_match /There are currently 0 nodes bound to this policy. Cannot lower max_count to -10/, output
end
