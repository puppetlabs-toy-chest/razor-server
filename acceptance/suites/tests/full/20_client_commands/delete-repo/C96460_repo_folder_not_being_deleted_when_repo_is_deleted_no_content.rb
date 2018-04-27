# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

teardown do
  agents.each{ |agent|
    on(agent, 'rm -rf /opt/puppetlabs/server/data/razor-server/repo/puppet-test-repo/')
  }
end

test_name 'C96459_repo_folder_not_being_deleted_when_repo_is_deleted_no_content'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/96460'

reset_database

razor agents, 'create-repo --name puppet-test-repo --task centos --no-content' do |agent|
  step "Verify that the repo is defined on #{agent}"
  text = on(agent, "razor repos").output
  assert_match /puppet-test-repo/, text
  on(agent, 'mkdir /opt/puppetlabs/server/data/razor-server/repo/puppet-test-repo/; touch /opt/puppetlabs/server/data/razor-server/repo/puppet-test-repo/testfile.txt')
end

razor agents, 'delete-repo --name puppet-test-repo' do |agent|
  step "Verify that the repo is no longer defined on #{agent}"
  text = on(agent, "razor repos").output
  refute_match /puppet-test-repo/, text
  step 'Verify that the repo folder is not deleted'
  text = on(agent, "if [ -f /opt/puppetlabs/server/data/razor-server/repo/puppet-test-repo/testfile.txt ] ; then echo 'folder not deleted' ; fi").output
  assert_match /folder not deleted/, text
end
