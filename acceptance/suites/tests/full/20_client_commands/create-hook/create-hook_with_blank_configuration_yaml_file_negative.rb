# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1820 - C59749 - create-hook with blank configuration.yaml file negative test'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59749'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = 'hookName1'
hook_path     = "#{hook_dir}/#{hook_type}.hook"

configuration_file =<<-EOF
EOF

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")

    #This is a negative test because it attempts to create a hook with undefined configuration object.
    # This test is different from https://testrail.ops.puppetlabs.net/index.php?/cases/view/63490
    # because it has a blank configuration.yaml while test case C63490 does not have the configuration.yaml
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar", \
              :acceptable_exit_codes => [1]) do |result|
      assert_match %r(error: configuration key 'value' is not defined for this hook type), result.stdout
    end
  end
end
