# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Create new user in shiro.ini'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59697'

config_yaml       = '/opt/puppetlabs/server/apps/razor-server/config-defaults.yaml'
shiro_ini         = '/etc/puppetlabs/razor-server/shiro.ini'

teardown do
  agents.each do |agent|
    restart_razor_service(agent)
  end
end

agents.each do |agent|
  with_backup_of(agent, config_yaml) do
    with_backup_of(agent, shiro_ini) do
      step "Enable authentication on #{agent}"
      config = on(agent, "cat #{config_yaml}").output
      yaml = YAML.load(config)
      yaml['all']['auth']['enabled'] = true
      config = YAML.dump(yaml)

      step "Create new #{config_yaml} on #{agent}"
      create_remote_file(agent, "#{config_yaml}", config)

      step "Create new user on  #{agent}"
      shiro = on(agent, "cat #{shiro_ini}").output
      # newUser's password is 'newPassword'
      new_file = shiro.gsub(/razor = 9b4f1d0e11dcc029c3493d945e44ee077b68978466c0aab6d1ce453aac5f0384, admin/, "razor = 9b4f1d0e11dcc029c3493d945e44ee077b68978466c0aab6d1ce453aac5f0384, admin\nnewUser = 5c29a959abce4eda5f0e7a4e7ea53dce4fa0f0abbe8eaa63717e2fed5f193d31, admin")

      create_remote_file(agent, "#{shiro_ini}", new_file)

      step "Verify shiro on #{agent}"
      verify_shiro_default(agent)

      step "Restart Razor Service on #{agent}"
      restart_razor_service(agent, "https://razor:razor@#{agent}:8151/api")

      step 'C59697: Authenticate to razor server #{agent} with newly created credentials'
      on(agent, "razor -u https://newUser:newPassword@#{agent}:8151/api") do |result|
        assert_match(/Collections:/, result.stdout, 'The request should be authorized')
      end
    end
  end
end
