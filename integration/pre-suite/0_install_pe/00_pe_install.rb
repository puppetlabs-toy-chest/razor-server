require 'razor_integration'
test_name 'Install Puppet Enterprise'

#Checks to make sure environment is capable of running tests.
razor_config?

step 'Install PE'
install_pe
