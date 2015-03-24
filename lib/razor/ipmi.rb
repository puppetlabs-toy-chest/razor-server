# -*- encoding: utf-8 -*-
require 'tempfile'
require 'open3'

# IPMI wrapper implementation.  This, sadly, works by finding and executing
# the external `ipmitool` command to interact with the remote system; the
# complexity of doing this with the libraries and FFI was prohibitive.
#
# This provides a synchronous interface to IPMI interactions with the remote
# system.  Most interactions with this module are expected to be mediated
# through the background messaging system in TorqueBox.
#
# This also implements an abstraction, delegating operations to a subclass
# determined at runtime.  By default only an `ipmitool` implementation exists,
# but testing likely demands an alternate implementation, and in the longer
# term we hopefully either obtain a pure Java/Ruby implementation, or
# something equally useful.
module Razor::IPMI
  def self.IPMIError(node, command, message)
    IPMIError.new(node, command, message)
  end

  class IPMIError < RuntimeError
    def initialize(node, command, message)
      super(message)
      @node    = node
      @command = command
    end

    attr_reader 'node', 'command'

    def to_s
      "node: #{node.name} command: #{command}\n" + super
    end
  end

  # query the BMC guid for a node
  def self.guid(node)
    output = run(node, 'bmc', 'guid')
    guids = output.lines.grep(/^System GUID/)

    if guids.empty?
      raise IPMIError(node, 'guid', "unable to find BMC GUID in output:\n#{output}")
    elsif guids.count > 1
      # I don't believe this will ever trigger, but....
      raise IPMIError(node, 'guid', "confused by finding multiple BMC GUID values:\n#{guids.inspect}\n#{output}")
    end

    # Split apart and extract the segment we care about from the output, which
    # looks like this:
    #
    # 1.9.3-p484 :006 > output.lines.grep(/^System GUID/).first
    # => "System GUID  : 31303043-534d-2500-90d8-7a5100000000\n"
    guids.first.split(':').last.strip
  end

  # query the current power state of the node; this does not track in-progress
  # changes in state, which is a limitation of the IPMI tools, so will still
  # show "on" while shutting down, or "off" while powering on.
  def self.power_state(node)
    output = run(node, 'power', 'status')
    if match = /Chassis Power is (on|off)/.match(output)
      match[1]
    else
      raise IPMIError(node, 'power_state', "output did not include power state:\n#{output}")
    end
  end

  def self.on?(node)
    power_state(node) == 'on'
  end

  def self.reset(node)
    output = run(node, 'power', 'cycle')
    unless output =~ /Chassis Power Control: Cycle/i
      raise IPMIError(node, 'reset', "output did not indicate reset operation:\n#{output}")
    end
    true
  end

  def self.power(node, on)
    output = run(node, 'power', on ? 'on' : 'off')
    unless output =~ %r(Chassis Power Control: #{on ? 'Up/On' : 'Down/Off'})i
      raise IPMIError(node, 'reset', "output did not indicate power state correctly:\n#{output}")
    end
    !!on
  end

  # This list is hard-coded from the set of boot device types that IPMItool
  # knows about, which in turn comes from (and matches) the IPMI spec, so it
  # shouldn't change any time soon.
  ValidBootDevices = %w{none pxe disk safe diag cdrom bios floppy}

  # Force a temporary boot device on the next restart; this can be used to
  # request a system boot via PXE, or other targets.
  def self.boot_from_device(node, device)
    unless ValidBootDevices.include? device
      raise IPMIError(node, 'boot_from_device', "device #{device.inspect} is not valid: #{ValidBootDevices.join(', ')}")
    end

    # @todo danielp 2013-12-04: we should probably support options here,
    # I guess, like EFI boot, password bypass or lock, and verbose.
    output = run(node, 'chassis', 'bootdev', device)
    match = /Set Boot Device to (.+)/.match(output)
    unless match[1] == device
      raise IPMIError(node, 'boot_from_device', "system responded with boot device #{match[1].inspect} not #{device.inspect}")
    end

    return true
  end


  private
  # Given a node, execute the IPMI command, and either return the output, or
  # raise an exception if the command fails.  This handles all the setup, and
  # in future things like "retry with a fancier protocol", or "enable
  # automatic work-arounds", or whatever, required to make the command
  # execution simple.
  #
  # If you update this, please also update `fake_run` in the spec tests.
  def self.run(node, *args)
    command = build_command(node, args)

    # Now we have our command, execute it and capture the output
    stdout, stderr = Open3.popen3(*command) do |i, o, e, wait|
      logger.info("running #{args.join(' ')} command on node #{node.id}")
      [i, o, e].map(&:binmode)
      # Push these into the background so we can avoid blocking if too much
      # output is generated, and one blocks before the other completes.
      #
      # These should be retained talking to separate buffers, to avoid
      # intermixing output from long processes in horrible ways.
      out_reader = Thread.new { o.read }
      err_reader = Thread.new { e.read }

      # send any input, of which we never have any.
      i.close

      # ...and check status of the process, which will wait until
      # it terminates.
      #
      # @todo danielp 2013-12-02: perhaps we should consider bounding the time
      # we will pause here?  Hopefully that can be handled at a higher layer.
      status = wait.value
      unless status.success?
        raise "executing #{command.inspect} failed: #{wait}\n#{err_reader.value}"
      end

      [out_reader.value, err_reader.value]
    end

    # Clean up the password file, if possible, to keep it living as little
    # time as possible.
    command.respond_to?('passfile') and command.passfile.close!

    # Finally, return the output to the caller.  Nobody cares for anything but
    # the combined output, so we pack it together here.
    stdout + "\n" + stderr
  end

  def self.build_command(node, args)
    node.ipmi_hostname or
      raise ArgumentError, _("node %{name} has no IPMI hostname set") % {name: node.name}

    command = %w{ipmitool -I lanplus}
    command.concat(['-H', node.ipmi_hostname])
    command.concat(['-U', node.ipmi_username]) if node.ipmi_username

    # We can use a secure temporary file to stash the password while we run
    # the command, which helps reduce the risk of exposure.  That means we
    # need to capture it at an appropriate scope to ensure it persists until
    # the end of the function and all.
    passfile = if node.ipmi_password
                 # we are mode 0600, and in a nice temporary directory, so we are
                 # about as safe as we can be.
                 file = Tempfile.new('ipmitool-password')
                 file.print(node.ipmi_password)
                 # Push data out to the OS; hopefully this is sufficient to make
                 # it visible to other processes.  If we start getting unexpected
                 # authentication failures because of wrong passwords, we can look
                 # at, eg, using fsync on this, or setting the file to sync mode.
                 file.flush rescue nil
                 file
               end

    # Now, add the password data iff we have a password.
    command.concat(['-f', passfile.path]) if passfile

    # Finally, add the command we were asked to run by the user.
    command.concat(args)

    # We also stash the passfile object itself on the command, for two key
    # reasons: first, to ensure that if a caller needs it they can get it.
    # Second, to ensure that the Tempfile object that contains the password
    # lives as long as the command array does -- so that it doesn't GC and
    # delete the scratch file at an inconvenient moment.  (This closes over
    # the local.)
    #
    # This is done last to avoid accidentally creating a new array that drops
    # the additional method. :)
    command.define_singleton_method('passfile') do passfile end

    # ...and back to the caller we go.
    command
  end

  def self.logger
    @logger ||= TorqueBox::Logger.new(self.class)
  end
end
