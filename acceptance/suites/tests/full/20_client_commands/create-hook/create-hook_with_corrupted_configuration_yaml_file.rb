# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1820 - C59748 - create-hook with corrupted configuration.yaml file'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59748'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = 'hookName1'
hook_path     = "#{hook_dir}/#{hook_type}.hook"

configuration_file =<<-EOF
---
value:
THIS IS A CORRUPTED CONFIGURATION.YAML FILE
  description: "The current value of the hook"
  default: 0
foo:
EOF

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")
    on(agent, "razor create-hook --name #{hook_name}" \
            " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar", \
            :acceptable_exit_codes => [1]) do |result|
      assert_match(/500 Internal Server Error/, result.stdout, 'Create hook test failed')
    end
  end
end
