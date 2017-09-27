# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "Create tag with Invalid JSON syntax"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/622"

reset_database
step 'Create the (deliberately invalid) JSON file containing the new tag definition'
json = '{
    "name" => "puppet-test-tag",
    "rule"  => {"=", 1, 2}
  }
  "this is clearly broken, observe the deliberately missing comma above me!"
  "also, that this is not valid object syntax"
}'

razor agents, 'create-tag', json, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/.*\.json is not valid JSON}, text
end

