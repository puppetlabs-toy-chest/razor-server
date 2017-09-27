# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Delete tag with long unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/660'

reset_database

name = unicode_string

json = {
    'name' => name,
    'rule' => ["=", ["fact", "processorcount"], "2"]
}
razor agents, 'create-tag', json do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags").output
  assert_match /#{Regexp.escape(name)}/, text
end

json = {
    'name' => name
}
razor agents, 'delete-tag', json do |agent|
  step "Verify that the tag is no longer defined on #{agent}"
  text = on(agent, "razor tags").output
  refute_match /#{Regexp.escape(name)}/, text
end
