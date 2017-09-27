# -*- encoding: utf-8 -*-
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Stop Razor Service'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/9'

step 'Stop Razor Service'
on agents, 'service pe-razor-server stop'

step 'Verify that the service is not operational'
agents.each do |agent|
  text = on(agent, "razor").output

  assert_match(/Could not connect to the server/, text)
end

step 'Start the Razor Service'
# the redirect to /dev/null is to work around a bug in the init script or
# service, per: https://tickets.puppetlabs.com/browse/RAZOR-247
on agents, 'service pe-razor-server start >&/dev/null'

step 'Verify start was successful'
agents.each do |agent|
  text = on(agent, "razor").output

  assert_match(/Usage: razor \[FLAGS\] NAVIGATION/, text,
    'The help information should be displayed')
end
