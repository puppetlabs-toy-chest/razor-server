# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create repo without name parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/598'

reset_database

razor agents, 'create-repo --url "http://provisioning.example.com/centos-6.4/x86_64/os/" --task centos', nil, exit: 1 do |agent, output|
  assert_match /name is a required attribute, but it is not present/, output
end