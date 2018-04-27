# -*- encoding: utf-8 -*-
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Restart Razor Service'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/8'

step 'Restart Razor Service'
# the redirect to /dev/null is to work around a bug in the init script or
# service, per: https://tickets.puppetlabs.com/browse/RAZOR-247
agents.each do |agent|
  restart_razor_service(agent)
end

step 'Verify restart was successful'
agents.each do |agent|
  text = on(agent, "razor").output

  assert_match(/Usage: razor \[FLAGS\] NAVIGATION/, text,
    'The help information should be displayed')
end
