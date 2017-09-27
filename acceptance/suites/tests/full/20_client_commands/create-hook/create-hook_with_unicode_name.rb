# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1818 - C59713 - create-hook with unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59713'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = unicode_string
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

delete_json = {
    'name' => hook_name
}

teardown do
  agents.each do |agent|
    razor(agent, 'delete-hook', delete_json)
  end
end

json = {
    'name' => hook_name,
    'hook_type' => hook_type,
    'c' => { 'value' => '5',
             'foo' => 'newFoo',
             'bar' => 'newBar' }
}

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")
    razor(agent, "create-hook", json)

    step 'Verify if the hook is successfully created:'
    on(agent, "razor -u https://razor-razor@#{agent}:8151/api hooks") do |result|
      assert_match(/#{Regexp.escape(hook_name)}/, result.stdout, 'razor create-hook failed')
    end
  end
end
