# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create repo with same name as existing repo'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/596'

reset_database

razor agents, 'create-repo --name puppet-test-repo --url "http://provisioning.example.com/centos-6.4/x86_64/os/" --task centos' do |agent|
  step "Verify that the repo is defined on #{agent}"
  text = on(agent, "razor repos").output
  assert_match /puppet-test-repo/, text
end

step 'Try to create slightly different repo'
razor agents, 'create-repo --name puppet-test-repo --url "http://not-the-same.example.com/centos-6.4/x86_64/os/" --task centos', nil, exit: 1 do |agent, output|
  assert_match /The repo puppet-test-repo already exists, and the url fields do not match/, output
end