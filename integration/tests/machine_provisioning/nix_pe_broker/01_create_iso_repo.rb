require 'razor_integration'
require 'razor_constants'
test_name 'QA-1788 - C59750 - Create a Razor Repo from an ISO URL'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

razor_server            = find_only_one(:razor_server)

#Init
cur_platform            = ENV['PLATFORM']

step "Get repo iso URL for Platform '#{cur_platform}'"
url_const               = "#{cur_platform}_ISO_URL"
iso_url                 = Object.const_get("#{url_const}")

step "Get repo name for Platform '#{cur_platform}'"
repo_const              = "#{cur_platform}_REPO_NAME"
repo_name               = Object.const_get("#{repo_const}")

step "Get task for Platform '#{cur_platform}'"
task_const              = "#{cur_platform}_TASK"
task                    = Object.const_get("#{task_const}")

create_iso_repo_command = "razor create-repo --name='#{repo_name}' --iso-url='#{iso_url}' --task='#{task}'"

#Verification
verify_repo_name_regex  = /name: #{repo_name}/
verify_repo_url_regex   = /iso_url: #{iso_url}/
verify_repo_task_regex  = /task: #{task}/
verify_repo_command     = "razor repos #{repo_name}"

step 'Create Repo and Verify'
on(razor_server, create_iso_repo_command) do |result|
  assert_match(verify_repo_name_regex, result.stdout, 'Broker name incorrectly configured!')
  assert_match(verify_repo_url_regex, result.stdout, 'Broker repo incorrectly configured!')
  assert_match(verify_repo_task_regex, result.stdout, 'Broker task incorrectly configured!')
end

step 'Sleep a Bit While ISO is Downloaded and Unpacked'
sleep(90)

step 'Verify Repo via Collection Lookup'
on(razor_server, verify_repo_command) do |result|
  assert_match(verify_repo_name_regex, result.stdout, 'Broker name not found!')
  assert_match(verify_repo_url_regex, result.stdout, 'Broker url  not found!')
  assert_match(verify_repo_task_regex, result.stdout, 'Broker task  not found!')
end
