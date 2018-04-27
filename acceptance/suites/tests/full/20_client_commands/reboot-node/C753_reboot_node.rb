# -*- encoding: utf-8 -*-
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C753 Reboot Node'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/753'

reset_database

step "create a node that we can set the power state of later"
json = {'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}}
razor agents, 'register-node', json do |node, text|
  _, nodeid = text.match(/name: (node\d+)/).to_a
  refute_nil nodeid, 'failed to extract node ID from output'

  # Set the IPMI details of that node.
  razor node, "set-node-ipmi-credentials", {
    'ipmi-hostname' => 'localhost', 'name' => nodeid
  }

  # Enqueue a reboot request for the node.
  razor node, "reboot-node", {'name' => nodeid} do |node, text|
    assert_match /reboot request queued/, text
  end
end
