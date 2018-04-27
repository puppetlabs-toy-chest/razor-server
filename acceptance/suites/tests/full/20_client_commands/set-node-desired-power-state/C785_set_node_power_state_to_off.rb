# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C785 Set Node Power State to "off"'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/785'

reset_database

step "create a node that we can set the power state of later"
json = {'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}}
razor agents, 'register-node', json do |node, text|
  _, nodeid = text.match(/name: (node\d+)/).to_a
  refute_nil nodeid, 'failed to extract node ID from output'

  json = {"name" => nodeid, "to" => "off"}
  razor node, 'set-node-desired-power-state', json do |node, text|
    assert_match /set desired power state to off/, text
  end
end
