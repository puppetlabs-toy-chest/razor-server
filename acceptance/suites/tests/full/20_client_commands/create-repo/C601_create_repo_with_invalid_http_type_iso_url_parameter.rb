# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create Repo with Invalid HTTP Type "--iso-url" Parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/601'

reset_database

razor agents, 'create-repo --name puppet-test-repo --task centos --iso-url "not-a-url"', nil, exit: 1 do |agent, output|
  assert_match /iso_url is invalid/, output
end