# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C797 Set Node Credentials with Invalid Path for JSON File"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/767"

require 'tmpdir'
file = '/tmp/' + Dir::Tmpname.make_tmpname(['set-node-ipmi-credentials', '.json'], nil)

step 'Ensure the temporary file is absolutely not present'
on agents, "rm -f #{file}"

reset_database
razor agents, 'set-node-ipmi-credentials', %W{--json #{file}}, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/set-node-ipmi-credentials.*\.json not found}, text
end
