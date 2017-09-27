# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1820 - C59742 - create-hook with missing required configuration parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59742'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = 'hook_name_2'
hook_path     = "#{hook_dir}/#{hook_type}.hook"

configuration_file =<<-EOF
---
value:
  description: "The current value of the hook"
  required: true
foo:
  description: "The current value of the hook"
  default: defaultFoo
bar:
  description: "The current value of the hook"
  default: defaultBar

EOF

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")

    step 'create hook with  missing hook configuration attr'
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type}", :acceptable_exit_codes => [1]) do |result| \
        assert_match %r(error: configuration key 'value' is required by this hook type, but was not supplied), result.stdout
    end
  end
end
