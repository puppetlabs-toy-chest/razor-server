# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C594 Create repo with Invalid JSON syntax"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/594"

reset_database
step 'Create the (deliberately invalid) JSON file containing the new repo definition'
json = '{
    "name" => "puppet-test-repo",
    "url"  => "http://provisioning.example.com/centos-6.4/x86_64/os/",
    "task" => "centos"
  }
  "this is clearly broken, observe the deliberately missing comma above me!"
  "also, that this is not valid object syntax"
}'

razor agents, 'create-repo', json, exit: 1 do |agent, text|
  assert_match %r{Error: File /tmp/.*\.json is not valid JSON}, text
end

