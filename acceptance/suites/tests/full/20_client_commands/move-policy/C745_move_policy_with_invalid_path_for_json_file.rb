# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}
require 'tmpdir'

test_name "Move policy with Invalid path for JSON File"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/745"

file = '/tmp/' + Dir::Tmpname.make_tmpname(['move-policy-', '.json'], nil)

step 'Ensure the temporary file is absolutely not present'
on agents, "rm -f #{file}"

reset_database
razor agents, 'move-policy', %W{--json #{file}}, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/move-policy.*\.json not found}, text
end

