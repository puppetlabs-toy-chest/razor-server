require 'master_manipulator'
require 'razor_integration'
test_name 'Install PE Razor on Node'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

step 'Pre-setup'
razor_server          = find_only_one(:razor_server)
razor_server_certname = on(razor_server, puppet('config', 'print', 'certname')).stdout.rstrip

master_certname       = on(master, puppet('config', 'print', 'certname')).stdout.rstrip
environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

#Init
#There is a known bug (RAZOR-392) that causes the gem installation to fail for documentation.
razor_client_gem_command = 'gem install pe-razor-client --no-ri'
razor_api_env_command = "echo \"export RAZOR_API=https://#{razor_server_certname}:8151/api\" > /etc/profile.d/razor_env.sh"
site_pp = create_site_pp(master_certname, manifest='  include pe_razor', node_def_name="'#{razor_server_certname}'")

# include pe_repo for razor node platform on the master
razor_node_platform_class = platform_class(ENV['PLATFORM'])
if(!razor_node_platform_class.empty?)
  step "Adding node platform repo to side.pp file: #{razor_node_platform_class}"
  site_pp = <<-MANIFEST
#{site_pp}
node "#{master_certname}.delivery.puppetlabs.net" {
   include "#{razor_node_platform_class}"
}
MANIFEST
end

#Setup
step 'Inject Node Definition for Razor Server on Master'
  inject_site_pp(master, prod_env_site_pp_path, site_pp)

#Run puppet agent -t to install pe_repo::Platform
if(!razor_node_platform_class.empty?)
  step "Download #{razor_node_platform_class} onto master node"
  retry_on(master, puppet('agent', '-t'), :max_retries => 10, :retry_interval => 10, :acceptable_exit_codes => [0,2])
end

step 'Disable Environment Caching on Master'
on(master, puppet('config', 'set environment_timeout 0', '--section main'))

step 'Restart the Puppet Server Service'
restart_puppet_server(master)

step 'Install PE Razor on Razor Server Host'
retry_on(razor_server, puppet('agent', '-t'), :max_retries => 10, :retry_interval => 10, :acceptable_exit_codes => [0,2])

step 'Install Razor Client Gem on Master and Razor Server'
on(master, razor_client_gem_command)
on(razor_server, razor_client_gem_command)

step 'Set the "RAZOR_API" Environment Variable on Master and Razor Server'
on(master, razor_api_env_command)
on(razor_server, razor_api_env_command)

step 'Get jq for hook script'
on(razor_server, "curl -Lo /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq")
on(razor_server, "chmod +x /usr/bin/jq")
