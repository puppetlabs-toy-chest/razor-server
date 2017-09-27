# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'C96242 - delete hook with positional arguments'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59734'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = 'hookName1'
hook_path     = "#{hook_dir}/#{hook_type}.hook"

configuration_file =<<-EOF
---
value:
  description: "The current value of the hook"
  default: 0
foo:
  description: "The current value of the hook"
  default: defaultFoo
bar:
  description: "The current value of the hook"
  default: defaultBar

EOF

teardown do
  agents.each do |agent|
    on(agent, "razor delete-hook --name #{hook_name}")
  end
end

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar")

    step 'Verify if the hook is successfully created:'
    on(agent, "razor hooks") do |result|
      assert_match(/#{hook_name}/, result.stdout, 'razor create-hook failed')
    end

    step 'Delete the newly created hook'
    on(agent, "razor delete-hook #{hook_name}") do |result|
      assert_match(/result: hook #{hook_name} destroyed/, result.stdout, 'test failed')
    end

    step "Verify that hook #{hook_name} is no longer defined on #{agent}"
    text = on(agent, "razor hooks").output
    refute_match /#{hook_name}/, text

  end
end
