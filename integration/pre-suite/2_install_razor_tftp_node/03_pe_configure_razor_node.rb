require 'razor_integration'
test_name 'Configure Razor Node'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

step 'Pre-setup'
razor_node = find_only_one(:razor_node)

#Init
facter_install_command = 'gem install facter'

#Setup
step 'Install Facter on Razor Node'
on(razor_node, facter_install_command)
