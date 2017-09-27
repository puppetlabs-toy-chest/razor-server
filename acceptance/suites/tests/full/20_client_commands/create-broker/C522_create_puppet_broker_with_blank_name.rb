# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C522 create puppet broker with blank name"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/522"

reset_database
json = {"name" => "", "broker-type" => "puppet"}

razor agents, 'create-broker', json, exit: 1 do |agent, text|
  assert_match /name must be between 1 and 250 characters in length, but is 0 characters long/, text
end

