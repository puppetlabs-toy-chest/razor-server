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

manifest_path = master.puppet('agent')['manifest']

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

# TODO Remove this when the shipped version of razor-admin reads
# either razor-server or pe-razor-server sysconfig. `razor-admin` currently
# looks for `razor-server.sysconfig` when it executes. This updates the binary
# wrapper to use `pe-razor-server.sysconfig` if it exists, otherwise
# `razor-server.sysconfig`.
servers.each do |server|
  on server, <<SH
cat > '/opt/puppetlabs/server/apps/razor-server/share/razor-server/bin/razor-binary-wrapper' <<'EOT'
#!/bin/sh
. /etc/puppetlabs/razor-server/razor-torquebox.sh

# If we support moving, this needs to change.
RAZOR_HOME='/opt/puppetlabs/server/apps/razor-server/share/razor-server'

# Make sure our Gemfile is found by the tool.  This is needed because Bundler
# checks for the Gemfile relative to the current working directory, not the
# code you are running -- so fails for anything, say, in the path. :/
export BUNDLE_GEMFILE="${RAZOR_HOME}/Gemfile"

# Load the sysconfig file for the service, primarily
# to get the RAZOR_CONFIG setting.
if [ -e /etc/sysconfig/pe-razor-server ]; then
  sysconfig='/etc/sysconfig/pe-razor-server'
elif [ -e /etc/sysconfig/razor-server ]; then
  sysconfig='/etc/sysconfig/razor-server'
fi
if [ ! -z "${sysconfig}" ]; then
  # Enable variable auto-exporting when we source the
  # sysconfig file so that the exec below doesn't drop
  # the variables set here. We can't export the vars
  # inside the sysconfig file due to the way systemd
  # parses the file.
  set -a
  . "${sysconfig}"
  set +a
fi

# Figure out what we were asked to execute.
exe="$(basename $0)"

# Find the executable, and run it directly, or fail out gracefully.
if test -f "${RAZOR_HOME}/bin/${exe}"; then
    exec "${RAZOR_HOME}/bin/${exe}" "$@"
elif test -f "${JRUBY_HOME}/bin/${exe}"; then
    exec "${JRUBY_HOME}/bin/${exe}"
else
    echo "unable to find the ${exe} command in razor or bundled gems!"
    exit 1
fi

EOT
SH
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
