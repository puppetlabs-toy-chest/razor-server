require 'master_manipulator'
require 'razor_integration'
test_name 'This is a workaround for ticket RE-4077'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

step 'Work around for bug RE-4077'
step 'Getting build number'
build_number = on(master, 'puppet -V').output
build_number = build_number.to_s.split('Puppet Enterprise ').last.chomp
build_number = build_number.to_s[0...-1]
puts "build number is: #{build_number}"

step 'update file /opt/puppet/share/puppet/modules/pe_razor/manifests/init.pp'
init_path = '/opt/puppet/share/puppet/modules/pe_razor/manifests'
on(master, "cp #{init_path}/init.pp #{init_path}/ori-init-pp")
init_file = on(master, "cat #{init_path}/init.pp").output

# Replace the line: $pe_tarball_base_url = "https://pm.puppetlabs.com/puppet-enterprise",
# by:
# $pe_tarball_base_url = "http://neptune.puppetlabs.lan/3.8/ci-ready",
init_file = init_file.gsub(/pe_tarball_base_url = \"https\:\/\/pm\.puppetlabs\.com\/puppet-enterprise\"/, "pe_tarball_base_url = \"http://neptune.puppetlabs.lan/3.8/ci-ready\"")

# Replace file_extenstion {...} by file_extension = "tar"
# and add the $pe_build = 3.8 ci ready latest build
init_file = init_file.gsub(/file_extension = \$::pe_build \? \{\n.*\n.*\n.*\}/, "file_extension = \"tar\"\n $pe_build = \"#{build_number}\"")

# Remove ${pe_build} in the $url link
init_file = init_file.gsub(/\$\{pe_tarball_base_url\}\/\$\{pe_build\}/, "${pe_tarball_base_url}")

# Copy the new /opt/puppet/share/puppet/modules/pe_razor/manifests/init.pp to master host
create_remote_file(master, "#{init_path}/init.pp", init_file)


