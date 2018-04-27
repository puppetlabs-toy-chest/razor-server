require 'master_manipulator'
require 'razor_integration'
test_name 'QA-1788 - C59755 - Deploy Operating System to Node with Razor'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

#Init
cur_platform                  = ENV['PLATFORM']
master_certname               = on(master, puppet('config', 'print', 'certname')).stdout.rstrip
environment_base_path         = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_path                 = File.join(environment_base_path, 'production')
prod_env_modules_path         = File.join(prod_env_path, 'modules')
prod_env_site_pp_path         = File.join(prod_env_path, 'manifests', 'site.pp')
auth_keys_module_files_path   = File.join(prod_env_modules_path, 'auth_keys', 'files')
razor_node                    = find_only_one(:razor_node)
razor_node_hostname           = fact_on(razor_node, 'hostname')
ssh_auth_keys                 = get_ssh_auth_keys(razor_node)

#Manifests
local_manifests_root_path     = ENV['MANIFESTS'] || 'manifests'
razor_node_manifest           = File.read(File.join(local_manifests_root_path, 'razor_node.pp'))
razor_node_ubuntu_manifest    = File.read(File.join(local_manifests_root_path, 'razor_node_ubuntu.pp'))

#Verification
verify_cert_command           = "cert list | grep '#{razor_node_hostname}'"

#Setup
step 'Write SSH Authorize Keys File to Master'
on(master, "mkdir -p #{auth_keys_module_files_path}")
create_remote_file(master, "#{auth_keys_module_files_path}/authorized_keys", ssh_auth_keys)
on(master, "chmod -R 755 #{auth_keys_module_files_path}")

#Test
# Ubuntu has PermitRootLogin without-password (instead of yes). The below work-around set PermitRootLogin to be 'yes'
# The better way to handle this by  using augeas as below:
## augeas { "sshd_config":
## context => "/files/etc/ssh/sshd_config",
##    changes => "set /file/etc/ssh/sshd_config/PermitRootLogin yes"
## }
# But it doesn't seeam to work on rhel7
#
if cur_platform.to_s.include? "UBUNTU"
  step 'set PermitRootLogin to be \'yes\''
  sshd_config_module_files_path = File.join(prod_env_modules_path, 'ssh', 'files')
  sshd_config_file              = on(razor_node, 'cat /etc/ssh/sshd_config').stdout
  sshd_config_file              = sshd_config_file.sub(/.*PermitRootLogin.*/, 'PermitRootLogin yes')
  on(master, "mkdir -p #{sshd_config_module_files_path}")
  create_remote_file(master, "#{sshd_config_module_files_path}/sshd_config", sshd_config_file)
  on(master, "chmod 755 #{sshd_config_module_files_path}/sshd_config")

  step 'Update "site.pp" for "production" Environment'
  inject_site_pp(master, prod_env_site_pp_path, create_site_pp(master_certname, razor_node_ubuntu_manifest))
else
  step 'Update "site.pp" for "production" Environment'
  inject_site_pp(master, prod_env_site_pp_path, create_site_pp(master_certname, razor_node_manifest))
end

step 'Reboot Razor Node to Begin Provisioning'
on(razor_node, 'shutdown -r 1 &')

step 'Wait for Provisioning to Finish'
sleep(480)

step 'Verify that Node Registered with Puppet Master'
retry_on(master, puppet(verify_cert_command), :max_retries => 40, :retry_interval => 20)

step 'Sign Cert for Razor Node'
on(master, puppet('cert sign --all'))

step 'Ping Razor Node'
retry_on(master, "ping -c 4 #{razor_node_hostname}", :max_retries => 24, :retry_interval => 10)

step 'Manually Kick Off Puppet Run on Razor Node'
on(razor_node, "/opt/puppet/bin/puppet agent  -t", :acceptable_exit_codes => [0,2])

step 'Verify that Razor Node is Fully Operational'
if cur_platform.to_s.include? "CENTOS" or cur_platform.to_s.include? "RHEL" or cur_platform.to_s.include? "UBUNTU"
  on(razor_node, 'cat /var/log/razor.log')
end

if cur_platform.to_s.include? "RHEL"
  step 'Unsubscribe RHN license for RHEL provisioning'
  on(razor_node, "subscription-manager remove --all")
  on(razor_node, "subscription-manager unregister" )
end
