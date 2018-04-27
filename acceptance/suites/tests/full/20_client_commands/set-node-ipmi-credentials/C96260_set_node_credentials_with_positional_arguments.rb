# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Set Node Credentials with Positional Arguments'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/794'

reset_database

step "create a node that we can set IPMI credentials on later"
json = {'installed' => true, 'hw-info' => {'net0' => '00:0c:29:08:06:e0'}}
razor agents, 'register-node', json do |node, text|
  _, nodeid = text.match(/name: (node\d+)/).to_a
  refute_nil nodeid, 'failed to extract node ID from output'

  step "skipping verification until https://tickets.puppetlabs.com/browse/RAZOR-277 is fixed"
  if false # https://tickets.puppetlabs.com/browse/RAZOR-277 is fixed
    step "verify that node #{nodeid} has no IPMI credentials"
    razor node, "nodes #{nodeid}" do |node, text|
      refute_match /ipmi/i, text
    end

    tests = [
      {'ipmi-hostname' => 'foo.example.com'},
      {'ipmi-hostname' => 'foo.example.com', 'ipmi-username' => 'fred'},
      {'ipmi-hostname' => 'foo.example.com', 'ipmi-password' => 'wilma'},
      {'ipmi-hostname' => 'foo.example.com', 'ipmi-username' => 'fred', 'ipmi-password' => 'wilma'},
    ]

    tests.each do |test|
      step "set the IPMI credentials of #{nodeid} using #{test.inspect}"
      razor node, "set-node-ipmi-credentials nodeid"

      step "verify that the IPMI credentials of #{nodeid} now match what we set"
      razor node, "nodes #{nodeid}" do |node, text|
        if hostname = test['ipmi-hostname']
          assert_match /ipmi-hostname:\s+"#{hostname}"/, text
        else
          refute_match /ipmi-hostname/, text
        end

        if username = test['ipmi-username']
          assert_match /ipmi-username:\s+"#{username}"/, text
        else
          refute_match /ipmi-username/, text
        end

        if password = test['ipmi-password']
          assert_match /ipmi-password:\s+"#{password}"/, text
        else
          refute_match /ipmi-password/, text
        end
      end
    end
  end
end
