# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name "C505 Create Broker with Invalid Broker-type"
step "https://testrail.ops.puppetlabs.net/index.php?/cases/view/505"

reset_database
json = {
  "name" => "pe",
  "configuration" =>{
    "server" => "10.18.235.100"
  },
  "broker-type" => "wrong-type"
}

razor agents, 'create-broker', json, exit: 1 do |agent, text|
  assert_match(/broker_type must be the name of an existing broker type, but is 'wrong-type'/, text)
end

