# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C784 Set Node Power State to "on"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/784'

reset_database

json = {"name" => "banana.example.com", "to" => "on"}
razor agents, 'set-node-desired-power-state', json, exit: 1 do |node, text|
  assert_match /name must be the name of an existing node, but is 'banana.example.com'/, text
end
