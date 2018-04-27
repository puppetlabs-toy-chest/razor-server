# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C523 create puppet broker without '--name' parameter"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/523"

razor agents, 'create-broker', %w{--broker-type puppet}, exit: 1 do |agent, text|
  assert_match /name is a required attribute, but it is not present/, text
end

