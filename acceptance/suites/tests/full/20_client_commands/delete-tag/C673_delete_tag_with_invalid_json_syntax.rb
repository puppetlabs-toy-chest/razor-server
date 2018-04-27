# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "Delete tag with Invalid Syntax for JSON File"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/662"

reset_database
step 'Create the (deliberately invalid) JSON file containing the arguments'
json = '{
  "name" => "puppet-test-tag"
  "this is clearly broken, observe the deliberately missing comma above me!"
  "also, that this is not valid object syntax"
}'

razor agents, 'delete-tag', json, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/.*\.json is not valid JSON}, text
end

