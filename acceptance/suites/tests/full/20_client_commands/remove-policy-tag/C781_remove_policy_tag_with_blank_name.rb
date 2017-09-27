# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove policy tag with nonexistent tag'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/781'

reset_database

razor agents, 'create-tag', {
    "name" => 'puppet-test-tag',
    "rule" => ["=", ["fact", "processorcount"], "8"]
}

razor agents, "remove-policy-tag --name '' --tag puppet-test-tag", nil, exit: 1 do |agent, output|
  assert_match /name must be the name of an existing policy, but is ''/, output
end