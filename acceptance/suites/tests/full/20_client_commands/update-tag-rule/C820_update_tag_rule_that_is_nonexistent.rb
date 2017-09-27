# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Update tag rule that is nonexistent'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/820'

reset_database

razor agents, 'update-tag-rule --name does-not-exist --rule \'["not", false]\'', nil, exit: 1 do |agent, output|
  assert_match /name must be the name of an existing tag, but is 'does-not-exist'/, output
end