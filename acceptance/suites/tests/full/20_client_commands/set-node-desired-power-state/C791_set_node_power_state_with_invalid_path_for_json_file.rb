# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C791 Set Node Power State with invalid path for JSON file'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/791'

reset_database

file = '/tmp/' + Dir::Tmpname.make_tmpname(['create-policy-', '.json'], nil)

step 'Ensure the temporary file is absolutely not present'
on agents, "rm -f #{file}"

step "create a node that we can set the power state of later"
json = {'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}}
razor agents, 'register-node', json do |node, text|
  _, nodeid = text.match(/name: (node\d+)/).to_a
  refute_nil nodeid, 'failed to extract node ID from output'

  json = '{"name" => nodeid, "to" => on}'
  razor node, 'set-node-desired-power-state', %W{--json #{file}}, exit: 1 do |node, text|
    assert_match %r{Error: File /tmp/.*\.json not found}, text
  end
end
