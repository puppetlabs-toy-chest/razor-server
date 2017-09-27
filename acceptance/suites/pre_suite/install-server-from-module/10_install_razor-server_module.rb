# -*- encoding: utf-8 -*-
require 'tmpdir'

servers = get_razor_hosts

skip_test "No available razor server hosts" if servers.empty?

test_name 'install razor-server'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/3'

def with_backup_of(host, path)
  Dir.mktmpdir('beaker-backup') do |dir|
    file = File.basename(path)
    scp_from host, path, dir
    begin
      yield
    ensure
      scp_to host, "#{dir}/#{file}", path
    end
  end
end

step 'disable the firewall on the razor server'
on servers, 'iptables --flush'

step 'add node definitions for servers to the master'

manifest_path = master.puppet('master')['manifest']

if manifest_path.end_with? '.pp'
  manifest = manifest_path
else
  manifest = "#{manifest_path}/site.pp"
end

with_backup_of master, manifest do
  on master, <<SH
cat >> #{manifest} <<EOT

# Added by 10_install_razor to test our node installing Razor
#{servers.map {|a| "node '#{a}' { include pe_razor }" }.join("\n")}

EOT
SH

  on master, "cat #{manifest}"

  # restart the puppet service to flush the environment cache and ensure the
  # following agent run receives a catalog that reflects the changes we made to
  # the master's site.pp
  bounce_service( master, master['puppetservice'] )
  on servers, puppet('agent -t'), acceptable_exit_codes: [0,2]
end

step 'Verify that Razor is installed on the nodes, and our database is correct'
servers.each do |server|
  retry_on server, 'curl -kf https://localhost:8151/api', :max_retries => 24, :retry_interval => 15
end
on servers, '/opt/puppetlabs/bin/razor-admin -e production check-migrations'

step 'Install ipmitool on razor server'
servers.each do |server|
  install_package server, 'ipmitool'
end
