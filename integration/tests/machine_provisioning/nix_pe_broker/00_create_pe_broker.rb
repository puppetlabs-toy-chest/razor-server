require 'erb'
require 'razor_integration'
test_name 'QA-1788 - C59751 - Configure Puppet Enterprise as Broker'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

#Init
razor_server                = find_only_one(:razor_server)
$master_hostname            = on(master, puppet('config', 'print', 'certname')).stdout.rstrip

#ERB Template for Broker
local_files_root_path       = ENV['FILES'] || 'files'
broker_json_template        = File.join(local_files_root_path, 'brokers/puppet-pe.json.erb')
broker_json_config          = ERB.new(File.read(broker_json_template)).result
broker_json_config_path     = '/tmp/pe_broker.json'
create_broker_command       = "razor create-broker --json #{broker_json_config_path}"

#Verification
verify_broker_name_regex    = /name: pe/
verify_broker_server_regex  = /server: #{$master_fqdn}/
verify_broker_command       = 'razor brokers pe'

#Write broker config to Razor server.
create_remote_file(razor_server, broker_json_config_path, broker_json_config)

step 'Create PE Broker and Verify'
on(razor_server, create_broker_command) do |result|
  assert_match(verify_broker_name_regex, result.stdout, 'Broker name incorrectly configured!')
  assert_match(verify_broker_server_regex, result.stdout, 'Broker server incorrectly configured!')
end

step 'Verify Broker via Collection Lookup'
on(razor_server, verify_broker_command) do |result|
  assert_match(verify_broker_name_regex, result.stdout, 'Broker name not found!')
  assert_match(verify_broker_server_regex, result.stdout, 'Broker server not found!')
end
