require 'spec_helper'

describe Razor::IPMI do
  let :node do Fabricate(:node) end
  let :hostname do Faker::Internet.domain_name      end
  let :username do Faker::Internet.user_name[0..19] end
  let :password do Faker::Internet.password[0..19]  end

  let :ipmi_node do Fabricate(:node, :ipmi_hostname => hostname) end


  context "when building ipmitool commands" do
    it "should raise an appropriate error when the node has no hostname" do
      node.ipmi_hostname.should be_nil
      expect {
        Razor::IPMI.guid(node)
      }.to raise_error ArgumentError, /node .* has no IPMI hostname/
    end

    it "should not give a username or password if none present" do
      node.set(:ipmi_hostname => hostname).save
      Razor::IPMI.build_command(node, []).should include(hostname)
    end

    it "should give username if present" do
      node.set(:ipmi_hostname => hostname, :ipmi_username => username).save
      Razor::IPMI.build_command(node, []).should include(hostname, username)
    end

    it "should give password if present, as a file" do
      node.set(:ipmi_hostname => hostname, :ipmi_password => password).save
      cmd = Razor::IPMI.build_command(node, [])
      cmd.should include(hostname)

      file = cmd[(cmd.index('-f') || fail("no password file argument")) + 1]
      File.read(file).should == password
    end

    it "should give both username and password if present" do
      node.set(:ipmi_hostname => hostname, :ipmi_username => username, :ipmi_password => password).save
      cmd = Razor::IPMI.build_command(node, [])
      cmd.should include(hostname, username)

      file = cmd[(cmd.index('-f') || fail("no password file argument")) + 1]
      File.read(file).should == password
    end

    context "password file handling" do
      it "should be a secure tempfile" do
        node.set(:ipmi_hostname => hostname, :ipmi_password => password).save
        cmd = Razor::IPMI.build_command(node, [])
        file = cmd[(cmd.index('-f') || fail("no password file argument")) + 1]

        stat = File.stat(file)
        (stat.mode & 0777).should == 0600
        stat.should_not be_world_readable
        stat.should_not be_world_writable
        stat.should be_file
      end

      # This is a bit implementation specific, but since it is important that
      # this keep on working, or we risk random GC driven failures....
      it "should include the tempfile object" do
        node.set(:ipmi_hostname => hostname, :ipmi_password => password).save
        cmd = Razor::IPMI.build_command(node, [])

        cmd.passfile.should be_an_instance_of Tempfile

        file = cmd[(cmd.index('-f') || fail("no password file argument")) + 1]
        file.should == cmd.passfile.path
      end
    end
  end


  context "with fake execution" do
    context "guid" do
      it "should raise if the host is not reachable" do
        fake_run(
          'bmc guid',
          'Get GUID command failed',
          "Address lookup for #{ipmi_node.ipmi_hostname} failed")

        expect {
          Razor::IPMI.guid(ipmi_node)
        }.to raise_error Razor::IPMI::IPMIError, /unable to find BMC GUID/
      end

      it "should return the GUID if it is present on stdout" do
        fake_run(
          'bmc guid',
          "System GUID  : 31303043-534d-2500-90d8-7a5100000000\nTimestamp    : 02/25/1996 01:47:47",
          '')

        Razor::IPMI.guid(ipmi_node).should == '31303043-534d-2500-90d8-7a5100000000'
      end

      it "should handle multiple GUID matches in the output sanely" do
        # I don't think this should ever, ever trigger, but better to test the
        # code that handles the oddity. :)
        fake_run('bmc guid', <<EOT, '')
System GUID  : 31303043-534d-2500-90d8-7a5100000000
System GUID  : 76859f93-b6fc-4cb7-8166-42aa5b40cd1c
Timestamp    : 02/25/1996 01:47:47
EOT


        expect {
          Razor::IPMI.guid(ipmi_node)
        }.to raise_error Razor::IPMI::IPMIError, /confused by finding multiple BMC GUID values/
      end
    end

    context "power state" do
      it "should return on correctly" do
        fake_run('power status', <<EOT, '')
Chassis Power is on
EOT
        Razor::IPMI.power_state(ipmi_node).should == 'on'
        Razor::IPMI.on?(ipmi_node).should be_true
      end

      it "should return off correctly" do
        fake_run('power status', <<EOT, '')
Chassis Power is off
EOT
        Razor::IPMI.power_state(ipmi_node).should == 'off'
        Razor::IPMI.on?(ipmi_node).should be_false
      end

      it "should fail if the string is unknown" do
        fake_run('power status', <<EOT, '')
Chassis Power is strange
EOT
        expect {
          Razor::IPMI.power_state(ipmi_node)
        }.to raise_error Razor::IPMI::IPMIError, /output did not include power state/

        expect {
          Razor::IPMI.on?(ipmi_node)
        }.to raise_error Razor::IPMI::IPMIError, /output did not include power state/
      end
    end

    context "power" do
      it "should power on successfully" do
        fake_run('power on', <<EOT, '')
Chassis Power Control: Up/On
EOT
        Razor::IPMI.power(ipmi_node, true)
      end

      it "should power off successfully" do
        fake_run('power off', <<EOT, '')
Chassis Power Control: Down/Off
EOT
        Razor::IPMI.power(ipmi_node, false)
      end
    end

    describe "boot_from_device" do
      it "should raise an error if a bad device name is passed" do
        expect {
          Razor::IPMI.boot_from_device(ipmi_node, 'cloud')
        }.to raise_error Razor::IPMI::IPMIError, /device "cloud" is not valid/
      end

      Razor::IPMI::ValidBootDevices.each do |dev|
        it "should return true if the boot device was set to #{dev}" do
          fake_run("chassis bootdev #{dev}", "Set Boot Device to #{dev}\n", '')
          Razor::IPMI.boot_from_device(ipmi_node, dev).should be_true
        end
      end

      it "should report an error if the boot device is not set as expected" do
        # I have no hardware that causes this report, and just made it up to
        # exercise the code path; it may never happen, but I don't want to
        # depend on that, because firmware.
        fake_run("chassis bootdev pxe", "Set Boot Device to Network\n", '')
        expect {
          Razor::IPMI.boot_from_device(ipmi_node, 'pxe')
        }.to raise_error Razor::IPMI::IPMIError, /system responded with boot device "Network" not "pxe"/
      end
    end

    describe "reset" do
      it "should return true if hard reset" do
        fake_run('power cycle', <<EOT, '')
Chassis Power Control: Cycle
EOT
        Razor::IPMI.reset(ipmi_node).should be_true
      end
    end

    ########################################################################
    # Support infrastructure for our external command execution.  Fun.
    FakeRunData = {}

    def fake_run(match, stdout, stderr)
      FakeRunData[match] = stdout + "\n" + stderr
    end

    # How to fixture a command execution.  This matches a regular expression
    # against the full command, and returns the requested stdout and stderr the
    # same way the original run operation did.
    before :each do
      Razor::IPMI.stub(:run) do |_, *args|
        cmd = args.join(' ')
        if match = FakeRunData.find {|match, result| cmd =~ /#{match}/ }
          match.last
        else
          raise ArgumentError, "no fake execution for #{cmd} found"
        end
      end
    end

    after :each do
      FakeRunData.clear
    end
  end
end
