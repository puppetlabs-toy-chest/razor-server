# -*- encoding: utf-8 -*-

class Razor::Command::CreateTask < Razor::Command
  summary "Create a new task, stored entirely in the database"
  description <<-EOT

Razor supports both tasks stored in the filesystem and tasks stored in the
database; in general, it is highly recommended that you store your tasks in
the filesystem. Details about that can be found [on the Wiki][tasks]

For production setups, you may want to store your tasks in the database.
This command allows you to do that, though it is absolutely not required.

[tasks]: https://github.com/puppetlabs/razor-server/wiki/Writing-tasks
  EOT

  example api: <<-EOT
Define the RedHat task included with Razor using this command:

    {
      "name":        "redhat6",
      "os":          "Red Hat Enterprise Linux",
      "description": "A basic installer for RHEL6",
      "boot_seq": {
        "1":       "boot_install",
        "default": "boot_local"
      }
      "templates": {
        "boot_install": "#!ipxe\\necho Razor <%= task.label %> task boot_call\\necho Installation node: <%= node_url  %>\\necho Installation repo: <%= repo_url %>\\n\\nsleep 3\\nkernel <%= repo_url(\"/isolinux/vmlinuz\") %> <%= render_template(\"kernel_args\").strip %> || goto error\\ninitrd <%= repo_url(\"/isolinux/initrd.img\") %> || goto error\\nboot\\n:error\\nprompt --key s --timeout 60 ERROR, hit 's' for the iPXE shell; reboot in 60 seconds && shell || reboot\\n",
        "kernel_args": "ks=<%= file_url(\"kickstart\") %> network ksdevice=bootif BOOTIF=01-${netX/mac}",
        "kickstart": "#!/bin/bash\\n# Kickstart for RHEL/CentOS 6\\n# see: http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-options.html\\n\\ninstall\\nurl --url=<%= repo_url %>\\ncmdline\\nlang en_US.UTF-8\\nkeyboard us\\nrootpw <%= node.root_password %>\\nnetwork --hostname <%= node.hostname %>\\nfirewall --enabled --ssh\\nauthconfig --enableshadow --passalgo=sha512 --enablefingerprint\\ntimezone --utc America/Los_Angeles\\n# Avoid having 'rhgb quiet' on the boot line\\nbootloader --location=mbr --append=\"crashkernel=auto\"\\n# The following is the partition information you requested\\n# Note that any partitions you deleted are not expressed\\n# here so unless you clear all partitions first, this is\\n# not guaranteed to work\\nzerombr\\nclearpart --all --initlabel\\nautopart\\n# reboot automatically\\nreboot\\n\\n# following is MINIMAL https://partner-bugzilla.redhat.com/show_bug.cgi?id=593309\\n%packages --nobase\\n@core\\n\\n%end\\n\\n%post --log=/var/log/razor.log\\necho Kickstart post\\ncurl -s -o /root/razor_postinstall.sh <%= file_url(\"post_install\") %>\\n\\n# Run razor_postinstall.sh on next boot via rc.local\\nif [ ! -f /etc/rc.d/rc.local ]; then\\n  # On systems using systemd /etc/rc.d/rc.local does not exist at all\\n  # though systemd is set up to run the file if it exists\\n  touch /etc/rc.d/rc.local\\n  chmod a+x /etc/rc.d/rc.local\\nfi\\necho bash /root/razor_postinstall.sh >> /etc/rc.d/rc.local\\nchmod +x /root/razor_postinstall.sh\\n\\ncurl -s <%= stage_done_url(\"kickstart\") %>\\n%end\\n############\\n",
        "post_install": "#!/bin/bash\\n\\nexec >> /var/log/razor.log 2>&1\\n\\necho \"Starting post_install\"\\n\\n# Wait for network to come up when using NetworkManager.\\nif service NetworkManager status >/dev/null 2>&1 && type -P nm-online; then\\n    nm-online -q --timeout=10 || nm-online -q -x --timeout=30\\n    [ \"$?\" -eq 0 ] || exit 1\\nfi\\n\\n<%= render_template(\"set_hostname\") %>\\n\\n<%= render_template(\"store_ip\") %>\\n\\n<%= render_template(\"os_complete\") %>\\n\\n# We are done\\ncurl -s <%= stage_done_url(\"finished\") %>\\n"
      }
    }
EOT

  example cli: <<-EOT
Define the RedHat task included with Razor using this command:

    razor create-task --name redhat-new --os "Red Hat Enterprise Linux" \\
        --description "A basic installer for RHEL6" \\
        --boot-seq 1=boot_install --boot_seq default=boot_local \\
        --templates "boot_install=#\!ipxe\\necho Razor <%= task.label %> task boot_call\\necho Installation node: <%= node_url  %>\\necho Installation repo: <%= repo_url %>\\n\\nsleep 3\\nkernel <%= repo_url(\"/isolinux/vmlinuz\") %> <%= render_template(\"kernel_args\").strip %> || goto error\\ninitrd <%= repo_url(\"/isolinux/initrd.img\") %> || goto error\\nboot\\n:error\\nprompt --key s --timeout 60 ERROR, hit 's' for the iPXE shell; reboot in 60 seconds && shell || reboot\\n" \\
        --templates kernel_args="ks=<%= file_url(\"kickstart\") %> network ksdevice=bootif BOOTIF=01-${netX/mac}" \\
        --templates kickstart="#\!/bin/bash\\n# Kickstart for RHEL/CentOS 6\\n# see: http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-options.html\\n\\ninstall\\nurl --url=<%= repo_url %>\\ncmdline\\nlang en_US.UTF-8\\nkeyboard us\\nrootpw <%= node.root_password %>\\nnetwork --hostname <%= node.hostname %>\\nfirewall --enabled --ssh\\nauthconfig --enableshadow --passalgo=sha512 --enablefingerprint\\ntimezone --utc America/Los_Angeles\\n# Avoid having 'rhgb quiet' on the boot line\\nbootloader --location=mbr --append=\"crashkernel=auto\"\\n# The following is the partition information you requested\\n# Note that any partitions you deleted are not expressed\\n# here so unless you clear all partitions first, this is\\n# not guaranteed to work\\nzerombr\\nclearpart --all --initlabel\\nautopart\\n# reboot automatically\\nreboot\\n\\n# following is MINIMAL https://partner-bugzilla.redhat.com/show_bug.cgi?id=593309\\n%packages --nobase\\n@core\\n\\n%end\\n\\n%post --log=/var/log/razor.log\\necho Kickstart post\\ncurl -s -o /root/razor_postinstall.sh <%= file_url(\"post_install\") %>\\n\\n# Run razor_postinstall.sh on next boot via rc.local\\nif [ ! -f /etc/rc.d/rc.local ]; then\\n  # On systems using systemd /etc/rc.d/rc.local does not exist at all\\n  # though systemd is set up to run the file if it exists\\n  touch /etc/rc.d/rc.local\\n  chmod a+x /etc/rc.d/rc.local\\nfi\\necho bash /root/razor_postinstall.sh >> /etc/rc.d/rc.local\\nchmod +x /root/razor_postinstall.sh\\n\\ncurl -s <%= stage_done_url(\"kickstart\") %>\\n%end\\n############\\n" \\
        --templates post_install="#\!/bin/bash\\n\\nexec >> /var/log/razor.log 2>&1\\n\\necho \"Starting post_install\"\\n\\n# Wait for network to come up when using NetworkManager.\\nif service NetworkManager status >/dev/null 2>&1 && type -P nm-online; then\\n    nm-online -q --timeout=10 || nm-online -q -x --timeout=30\\n    [ \"$?\" -eq 0 ] || exit 1\\nfi\\n\\n<%= render_template(\"set_hostname\") %>\\n\\n<%= render_template(\"store_ip\") %>\\n\\n<%= render_template(\"os_complete\") %>\\n\\n# We are done\\ncurl -s <%= stage_done_url(\"finished\") %>\\n"

With positional arguments, this can be shortened::

    razor create-task redhat-new --os "Red Hat Enterprise Linux"
        --description "A basic installer for RHEL6" \\
        --boot-seq 1=boot_install --boot_seq default=boot_local \\
        --templates "boot_install=#\!ipxe\\necho Razor <%= task.label %> task boot_call\\necho Installation node: <%= node_url  %>\\necho Installation repo: <%= repo_url %>\\n\\nsleep 3\\nkernel <%= repo_url(\"/isolinux/vmlinuz\") %> <%= render_template(\"kernel_args\").strip %> || goto error\\ninitrd <%= repo_url(\"/isolinux/initrd.img\") %> || goto error\\nboot\\n:error\\nprompt --key s --timeout 60 ERROR, hit 's' for the iPXE shell; reboot in 60 seconds && shell || reboot\\n" \\
        --templates kernel_args="ks=<%= file_url(\"kickstart\") %> network ksdevice=bootif BOOTIF=01-${netX/mac}" \\
        --templates kickstart="#\!/bin/bash\\n# Kickstart for RHEL/CentOS 6\\n# see: http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-options.html\\n\\ninstall\\nurl --url=<%= repo_url %>\\ncmdline\\nlang en_US.UTF-8\\nkeyboard us\\nrootpw <%= node.root_password %>\\nnetwork --hostname <%= node.hostname %>\\nfirewall --enabled --ssh\\nauthconfig --enableshadow --passalgo=sha512 --enablefingerprint\\ntimezone --utc America/Los_Angeles\\n# Avoid having 'rhgb quiet' on the boot line\\nbootloader --location=mbr --append=\"crashkernel=auto\"\\n# The following is the partition information you requested\\n# Note that any partitions you deleted are not expressed\\n# here so unless you clear all partitions first, this is\\n# not guaranteed to work\\nzerombr\\nclearpart --all --initlabel\\nautopart\\n# reboot automatically\\nreboot\\n\\n# following is MINIMAL https://partner-bugzilla.redhat.com/show_bug.cgi?id=593309\\n%packages --nobase\\n@core\\n\\n%end\\n\\n%post --log=/var/log/razor.log\\necho Kickstart post\\ncurl -s -o /root/razor_postinstall.sh <%= file_url(\"post_install\") %>\\n\\n# Run razor_postinstall.sh on next boot via rc.local\\nif [ ! -f /etc/rc.d/rc.local ]; then\\n  # On systems using systemd /etc/rc.d/rc.local does not exist at all\\n  # though systemd is set up to run the file if it exists\\n  touch /etc/rc.d/rc.local\\n  chmod a+x /etc/rc.d/rc.local\\nfi\\necho bash /root/razor_postinstall.sh >> /etc/rc.d/rc.local\\nchmod +x /root/razor_postinstall.sh\\n\\ncurl -s <%= stage_done_url(\"kickstart\") %>\\n%end\\n############\\n" \\
        --templates post_install="#\!/bin/bash\\n\\nexec >> /var/log/razor.log 2>&1\\n\\necho \"Starting post_install\"\\n\\n# Wait for network to come up when using NetworkManager.\\nif service NetworkManager status >/dev/null 2>&1 && type -P nm-online; then\\n    nm-online -q --timeout=10 || nm-online -q -x --timeout=30\\n    [ \"$?\" -eq 0 ] || exit 1\\nfi\\n\\n<%= render_template(\"set_hostname\") %>\\n\\n<%= render_template(\"store_ip\") %>\\n\\n<%= render_template(\"os_complete\") %>\\n\\n# We are done\\ncurl -s <%= stage_done_url(\"finished\") %>\\n"
EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250, position: 0,
                help: _('The name of the task.')

  attr 'os', type: String, required: true, size: 1..1000,
             help: _('A description of the OS to be installed.')

  object 'templates', required: true, help: _(<<-HELP) do
    The templates used for task stages.  These are named.
  HELP
    extra_attrs type: String
  end

  object 'boot_seq', help: _(<<-HELP) do
    The boot sequence -- this is the list of template names to be applied
    at each stage through the boot sequence of the node.
  HELP
    attr 'default', type: String,
                    help: _('The template to use when no other template applies.')

    extra_attrs /^[0-9]+/, type: String
  end

  def run(request, data)
    # If boot_seq is not a Hash, the model validation for tasks
    # will catch that, and will make saving the task fail
    if (boot_seq = data["boot_seq"]).is_a?(Hash)
      # JSON serializes integers as strings, undo that
      boot_seq.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
        each { |k| boot_seq[k.to_i] = boot_seq.delete(k) }
    end

    Razor::Data::Task.import(data).first
  end
end
