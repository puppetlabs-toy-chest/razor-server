# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete repo with long name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/660'

reset_database

razor agents, 'create-repo --name ' + ('a' * 250) + ' --url "http://provisioning.example.com/centos-6.4/x86_64/os/" --task centos' do |agent|
  step "Verify that the repo is defined on #{agent}"
  text = on(agent, "razor repos").output
  assert_match /#{'a' * 250}/, text
end

razor agents, 'delete-repo --name ' + ('a' * 250) do |agent|
  step "Verify that the repo is no longer defined on #{agent}"
  text = on(agent, "razor repos").output
  refute_match /#{'a' * 250}/, text
end
