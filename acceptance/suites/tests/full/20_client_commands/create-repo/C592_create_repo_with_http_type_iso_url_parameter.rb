# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create repo with http type iso-url parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/592'

reset_database

razor agents, 'create-repo --name puppet-test-repo --iso-url "http://provisioning.example.com/centos-6.4/x86_64/os/" --task centos' do |agent|
  step "Verify that the repo is defined on #{agent}"
  text = on(agent, "razor repos").output
  assert_match /puppet-test-repo/, text
end