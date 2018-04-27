require 'net/ssh'

# Get the PE version (major/minor) installed on a host.
#
# ==== Attributes
#
# * +master+ - The Puppet master to check for version.
#
# ==== Returns
#
# +float+ - A floating point number representing the major/minor release for PE.
#
# ==== Examples
#
# pe_ver = get_pe_version(master)
def get_pe_version(master)
  pe_major = on(master, 'facter -p pe_major_version').stdout.rstrip
  pe_minor = on(master, 'facter -p pe_minor_version').stdout.rstrip

  return "#{pe_major}.#{pe_minor}".to_f
end

# Verify that a master is running a bare minimum version of Puppet Enterprise.
# Will fail or skip a test if minimum requirements are not met.
#
# ==== Attributes
#
# * +master+ - The Puppet master to check for version.
# * +min_version+ - The minimum allowed version of PE represented as a float.
# * +action+ - The action to take when check fails. (:fail, :skip)
#
# ==== Returns
#
# nil
#
# ==== Examples
#
# pe_version_check(master, 3.7, :fail)
def pe_version_check(master, min_version, action=:skip)
  assert_message = "This test requires PE #{min_version} or above!"

  if get_pe_version(master) < min_version
    if action == :skip
      skip_test(assert_message)
    elsif action == :fail
      fail_test(assert_message)
    end
  end
end

# Verify that the Beaker configuration file used during the test run contains
# host entries with correct Razor roles.
#
# ==== Attributes
#
# * +action+ - The action to take when check fails. (:fail, :skip)
#
# ==== Returns
#
# nil
#
# ==== Examples
#
# razor_config?(:fail)
def razor_config?(action=:skip)
  assert_message = 'Cannot run this test with specified Beaker configuration!'

  if not (any_hosts_as?(:razor_server) or any_hosts_as?(:razor_node))
    if action == :skip
      skip_test(assert_message)
    elsif action == :fail
      fail_test(assert_message)
    end
  end
end

# Get SSH authorize keys file content for current user.
#
# ==== Attributes
#
# * +host+ - The host from which to obtain the authorize keys content.
#
# ==== Returns
#
# nil
#
# ==== Examples
#
# razor_config?(:fail)
def get_ssh_auth_keys(host)
  return on(host, 'cat ~/.ssh/authorized_keys').stdout
end

# Connect to any host using SSH and a password. Will raise a assert failure if connection
# can't be made or command fails.
#
# ==== Attributes
#
# * +hostname+ - The hostname of target machine.
# * +username+ - The user to use for the SSH connection.
# * +password+ - The password to use for the SSH connection.
# * +command+ - The command to execute on host.
# * +exit_codes+ - The allowable exit codes for the command. (Array)
# * +return_output+ - A flag indicating if you want the output back from the command.
#
# ==== Returns
#
# nil
#
# ==== Examples
#
# ssh_with_password('puppet', 'root', 'password', 'ls -l /moo, exit_codes = [1], stdout = true)
def ssh_with_password(hostname, username, password, command, exit_codes = [0], stdout = false)
  stdout_data = ""
  exit_code = nil

  begin
    Net::SSH.start(hostname, username, :password => password) do |ssh_session|
      ssh_session.open_channel do |channel|
        channel.exec(command) do |ch, success|
          unless success
            abort "FAILED: couldn't execute command"
          end

          channel.on_data do |ch, data|
            stdout_data += data
          end

          channel.on_request("exit-status") do |ch, data|
            exit_code = data.read_long.to_i
          end
        end
      end
      ssh_session.loop
    end
  rescue
    fail_test("Unable to connect to #{hostname}!")
  end

  if not Array(exit_codes).include?(exit_code)
    fail_test("Unexpected exit code returned: #{exit_code}!")
  end

  if stdout
    return stdout_data
  end
end
