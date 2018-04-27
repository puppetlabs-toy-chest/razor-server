# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C793 Set Node Power State with invalid state'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/793'

reset_database

step "create a node that we can set the power state of later"
json = {'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}}
razor agents, 'register-node', json do |node, text|
  _, nodeid = text.match(/name: (node\d+)/).to_a
  refute_nil nodeid, 'failed to extract node ID from output'

  ['booted', 'reset', 1, 0, true, false].each do |state|
    step "testing invalid state #{state.inspect} on #{node}"
    json = {"name" => nodeid, "to" => state}
    razor node, 'set-node-desired-power-state', json, exit: 1 do |node, text|
      assert_match /to must refer to one of on, off, null|to should be a string, but was actually a (number|boolean)/, text
    end
  end
end
