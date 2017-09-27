# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1820 - C63491 - create-hook no hook directory'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/63491'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'does_not_exist'
hook_name     = 'hookName1'

step "Create hook type"
agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar", \
              :acceptable_exit_codes => [1]) do |result|
      assert_match %r(error: hook_type must be the name of an existing hook type, but is \'#{hook_type}\'), result.stdout
    end
  end
end
