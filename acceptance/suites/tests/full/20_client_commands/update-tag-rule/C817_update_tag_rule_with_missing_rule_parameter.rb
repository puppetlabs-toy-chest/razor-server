# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Update tag rule with missing rule parameter'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/817'

reset_database

tag_name = 'puppet-test-tag'

razor agents, 'create-tag --name ' + tag_name + ' --rule \'["=", ["fact", "processorcount"], "20520"]\'' do |agent|
  step "Verify that the tag is defined on #{agent}"
  text = on(agent, "razor tags #{tag_name}").output
  assert_match /20520/, text

  razor agent, 'update-tag-rule --name ' + tag_name, nil, exit: 1 do |agent, output|
    assert_match /rule is a required attribute, but it is not present/, output
  end
end