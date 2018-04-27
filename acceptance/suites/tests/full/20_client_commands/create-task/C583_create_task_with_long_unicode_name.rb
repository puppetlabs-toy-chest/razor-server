# -*- encoding: utf-8 -*-
require 'razor/acceptance/utils'
confine :except, :roles => %w{master dashboard database frictionless}

require 'tmpdir'

test_name 'Create task with long unicode name'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/583'

reset_database
# Note: this JSON is as specified in the testrail test case.
step 'Create the JSON file containing the new task definition'
# Task names cannot contain '$'
name = long_unicode_string('$')
json = {
  "name" => name,
  "os" => "Red Hat Enterprise Linux",
  "boot_seq" =>{
    "1" => "boot_install",
    "default" => "boot_local"
  },
  "templates" =>{
    "boot_install" => "#!ipxe\necho Razor <%= task.label %> task boot_call\necho Installation node: <%= node_url %>\necho Installation repo: <%= repo_url %>\n\nsleep 3\nkernel <%= repo_url(\"/isolinux/vmlinuz\") %> <%= render_template(\"kernel_args\").strip %> || goto error\ninitrd <%= repo_url(\"/isolinux/initrd.img\") %> || goto error\nboot\n:error\nprompt --key s --timeout 60 ERROR, hit 's' for the iPXE shell; reboot in 60 seconds && shell || reboot\n",
    "kernel_args" => "ks=<%= file_url(\"kickstart\") %> network ksdevice=bootif BOOTIF=01-${netX/mac}",
    "kickstart" => "#!/bin/bash\n# Kickstart for RHEL/CentOS 6\n# see: http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-options.html\n\ninstall\nurl --url=<%= repo_url %>\ncmdline\nlang en_US.UTF-8\nkeyboard us\nrootpw <%= node.root_password %>\nnetwork --hostname <%= node.hostname %>\nfirewall --enabled --ssh\nauthconfig --enableshadow --passalgo=sha512 --enablefingerprint\ntimezone --utc America/Los_Angeles\n# Avoid having 'rhgb quiet' on the boot line\nbootloader --location=mbr --append=\"crashkernel=auto\"\n# The following is the partition information you requested\n# Note that any partitions you deleted are not expressed\n# here so unless you clear all partitions first, this is\n# not guaranteed to work\nzerombr\nclearpart --all --initlabel\nautopart\n# reboot automatically\nreboot\n\n# followig is MINIMAL https://partner-bugzilla.redhat.com/show_bug.cgi?id=593309\n%packages --nobase\n@core\n\n%end\n\n%post --log=/var/log/razor.log\necho Kickstart post\ncurl -s -o /root/razor_postinstall.sh <%= file_url(\"post_install\") %>\n\n# Run razor_postinstall.sh on next boot via rc.local\nif [ ! -f /etc/rc.d/rc.local ]; then\n # On systems using systemd /etc/rc.d/rc.local does not exist at all\n # though systemd is set up to run the file if it exists\n touch /etc/rc.d/rc.local\n chmod a+x /etc/rc.d/rc.local\nfi\necho bash /root/razor_postinstall.sh >> /etc/rc.d/rc.local\nchmod +x /root/razor_postinstall.sh\n\ncurl -s <%= stage_done_url(\"kickstart\") %>\n%end\n############\n",
    "post_install" => "#!/bin/bash\n\nexec >> /var/log/razor.log 2>&1\n\necho \"Starting post_install\"\n\n# Wait for network to come up when using NetworkManager.\nif service NetworkManager status >/dev/null 2>&1 && type -P nm-online; then\n nm-online -q --timeout=10 || nm-online -q -x --timeout=30\n [ \"$?\" -eq 0 ] || exit 1\nfi\n\n<%= render_template(\"set_hostname\") %>\n\n<%= render_template(\"store_ip\") %>\n\n# @todo lutter 2013-09-12: we should register the system with RHN; be\n# careful though, since this file is also used by the CentOS installer, for\n# which there is no RHN registration\n\n<%= render_template(\"os_complete\") %>\n\n# We are done\ncurl -s <%= stage_done_url(\"finished\") %>\n"
  }
}

razor agents, 'create-task', json do |agent|
  step "Verify the task is defined on #{agent}"
  text = on(agent, "razor tasks").output
  assert_match /#{Regexp.escape(name)}/, text
end

