# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create repo with long name (250 characters)'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/590'

reset_database

json = {
    "name" => "a" * 250,
    "url"  => "http://provisioning.example.com/centos-6.4/x86_64/os/",
    "task" => "centos"
}

razor agents, 'create-repo', json do |agent|
  step "Verify that the repo is defined on #{agent}"
  text = on(agent, "razor repos").output
  assert_match /#{'a' * 250}/, text
end