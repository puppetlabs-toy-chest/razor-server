# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Update tag rule with positional arguments'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/810'

reset_database

tag_name = 'puppet-test-tag'

razor agents, 'create-tag --name ' + tag_name + ' --rule \'["=", ["fact", "processorcount"], "20520"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags #{tag_name}").output
  assert_match /20520/, text

  razor agent, 'update-tag-rule ' + tag_name + ' \'["=", ["fact", "processorcount"], "454545"]\'' do |agent|
    step "Verify that the tag is updated on #{agent}"
    text = on(agent, "razor tags #{tag_name}").output
    assert_match /454545/, text
  end
end
