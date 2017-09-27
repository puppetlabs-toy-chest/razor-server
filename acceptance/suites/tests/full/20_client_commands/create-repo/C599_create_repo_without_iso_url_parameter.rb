# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create repo without iso-url parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/599'

reset_database

razor agents, 'create-repo --name puppet-test-repo --task centos', nil, exit: 1 do |agent, output|
  assert_match /the command requires one out of the iso_url, no_content, url attributes to be supplied/, output
end