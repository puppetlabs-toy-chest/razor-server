# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Remove policy tag without name parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/782'

reset_database

razor agents, 'create-tag', {
    "name" => 'puppet-test-tag',
    "rule" => ["=", ["fact", "processorcount"], "6"]
}

razor agents, "remove-policy-tag --tag puppet-test-tag", nil, exit: 1 do |agent, output|
  assert_match /name is a required attribute, but it is not present/, output
end