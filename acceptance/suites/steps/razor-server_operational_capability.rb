# -*- encoding: utf-8 -*-
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Razor Server Operational Capability'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/5'

step 'Verify that Razor is responding correctly'
agents.each do |agent|
  # Not installed by default in my testing.  Hopefully this is portable enough
  # when we add more than centos as a SUT.
  install_package agent, 'wget'

  on agent, "wget --no-check-certificate https://#{agent}:8151/api -O /tmp/test.out"
  on agent, 'grep commands/set-node-hw-info /tmp/test.out'
end

