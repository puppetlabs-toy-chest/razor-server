require 'erb'
require 'razor_integration'
require 'razor_constants'
test_name 'QA-1788 - C59754 - Create a Policy for Razor Provisioning (rhel7)'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

#Init
razor_server            = find_only_one(:razor_server)
razor_node              = find_only_one(:razor_node)

razor_node_hostname     = fact_on(razor_node, 'hostname')
razor_node_serialnumber = fact_on(razor_node, 'serialnumber')

#Getting the Platform
cur_platform = ENV['PLATFORM']

#ERB Template for Tag
local_files_root_path = ENV['FILES'] || 'files'
create_tag_command = "razor create-tag --name #{razor_node_hostname} --rule '[\"=\", [\"fact\", \"serialnumber\"], \"#{razor_node_serialnumber}\"]'"

step "Get repo name for Platform '#{cur_platform}'"
repo_const      = "#{cur_platform}_REPO_NAME"
repo_name       = Object.const_get("#{repo_const}")

step "Get task for Platform '#{cur_platform}'"
task_const      = "#{cur_platform}_TASK"
task            = Object.const_get("#{task_const}")

step "Get broker for Platform '#{cur_platform}'"
broker_const    = "#{cur_platform}_BROKER"
broker          = Object.const_get("#{broker_const}")

#Construct Variables for Policy Template
$policy_name    = "#{cur_platform}_#{razor_node_hostname}"
$repo           = "#{repo_name}"
$task           = "#{task}"
$broker         = "#{broker}"
$hostname       = razor_node_hostname
$tag            = razor_node_hostname

#ERB Template for Policy
# If platfrom is RHEL, the policy should use rhel_RHN_policy.json.erb that has  RHN subscription
if cur_platform.to_s.include? "RHEL"
   policy_json_template     = File.join(local_files_root_path, 'policies/rhel_RHN_policy.json.erb')
else
  policy_json_template      = File.join(local_files_root_path, 'policies/basic_policy.json.erb')
end

policy_json_config          = ERB.new(File.read(policy_json_template)).result
policy_json_config_path     = '/tmp/policy.json'
create_policy_command       = "razor create-policy --json #{policy_json_config_path}"

#Verification
verify_policy_name_regex    = /name: #{$policy_name}/
verify_policy_repo_regex    = /repo: #{$repo}/
verify_policy_task_regex    = /task: #{$task}/
verify_policy_broker_regex  = /broker: #{$broker}/
verify_policy_command       = "razor policies #{$policy_name}"

#Write the metrics template to the Puppet Server config.
create_remote_file(razor_server, policy_json_config_path, policy_json_config)

step 'Create Tag for Razor Node'
on(razor_server, create_tag_command)

step 'Create Policy and Verify'
on(razor_server, create_policy_command) do |result|
  assert_match(verify_policy_name_regex, result.stdout, 'Policy name incorrectly configured!')
  assert_match(verify_policy_repo_regex, result.stdout, 'Policy repo incorrectly configured!')
  assert_match(verify_policy_task_regex, result.stdout, 'Policy task incorrectly configured!')
  assert_match(verify_policy_broker_regex, result.stdout, 'Policy broker incorrectly configured!')
end

step 'Verify Policy via Collection Lookup'
on(razor_server, verify_policy_command) do |result|
  assert_match(verify_policy_name_regex, result.stdout, 'Policy name not found!')
  assert_match(verify_policy_repo_regex, result.stdout, 'Policy repo not found!')
  assert_match(verify_policy_task_regex, result.stdout, 'Policy task not found!')
  assert_match(verify_policy_broker_regex, result.stdout, 'Policy broker not found!')
end
