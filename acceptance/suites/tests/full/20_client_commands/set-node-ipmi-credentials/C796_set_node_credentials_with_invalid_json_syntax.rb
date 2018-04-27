# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C796 Set Node Credentials with invalid JSON syntax'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/796'

reset_database

step 'Create the (deliberately invalid) JSON file containing the IPMI credentials'
json = "'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}"

razor agents, 'set-node-ipmi-credentials', json, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/.*\.json is not valid JSON}, text
end
