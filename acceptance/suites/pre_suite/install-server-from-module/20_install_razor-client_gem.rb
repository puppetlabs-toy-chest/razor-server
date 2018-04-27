# -*- encoding: utf-8 -*-
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'Install Razor Client'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/6'

step 'Install the Razor client'
# This can use the FOSS razor-client gem too. Ideally, a private
# repository would be used to allow referencing not-yet-released
# versions of pe-razor-client. When new versions of razor-client
# are released, acceptance testing should be done on razor-client
# rather than pe-razor-client since razor-client is more like future
# PE versions.
# `--no-ri` is included here because this was otherwise resulting
# in an error when it came to install razor-client:
# "undefined method `map' for Gem::Specification:Class"
# The other potential fix is to do `gem update --system`, which is
# a larger system change.
on agents, '/opt/puppetlabs/puppet/bin/gem install --clear-sources --source http://rubygems.delivery.puppetlabs.net pe-razor-client --no-ri'
# Symlink razor into the path so just `razor` works.
on agents, 'ln -s /opt/puppetlabs/puppet/bin/razor /usr/bin/razor'

step 'Print Razor help, and check for JSON warning'
agents.each do |agent|
  text = on(agent, "razor").output

  assert_match(/Usage: razor \[FLAGS\] NAVIGATION/, text,
    'The help information should be displayed')

  warning = Regexp.new(Regexp.escape('[WARNING] MultiJson is using the default adapter (ok_json).We recommend loading a different JSON library to improve performance.'))
  step "Check whether warning is present"
  # Some versions of Ruby have this warning; this should verify it can be removed.
  if warning =~ text
    step "Install json_pure"
    on agents, 'gem install json_pure'

    step "Verify JSON warning is gone"
    agents.each do |agent|
      text = on(agent, "razor").output

      assert_match(/Usage: razor \[FLAGS\] NAVIGATION/, text,
                   'The help information should be displayed')

      # Try a bunch of different things to try and be confident that changes in
      # error formatting don't cause us grief tomorrow.
      warning = Regexp.new(Regexp.escape('[WARNING] MultiJson is using the default adapter (ok_json).We recommend loading a different JSON library to improve performance.'))
      assert_no_match warning, text, 'The JSON warning should not be present any longer'
      assert_no_match /ok_json/, text, 'The JSON warning should not be present any longer'
      assert_no_match /MultiJson/, text, 'The JSON warning should not be present any longer'
    end
  end
end

