# -*- encoding: utf-8 -*-

class Razor::Command::RegisterNode < Razor::Command
  summary "Register a node with Razor before it is discovered"
  description <<-EOT
In order to make brownfield deployments of Razor easier we allow users to
register nodes explicitly.  This command allows you to perform the same
registration that would happen when a new node checked in, ahead of time.

In order for this to be effective the hw_info must contain enough information
that the node can successfully be matched during the iPXE boot phase.

If the node matches an existing node, in keeping with the overall policy of
commands declaring desired state, the node installed field will be updated to
match the value in this command.

The final state is that a node with the supplied hardware information, and the
desired installed state, will be present in the database, regardless of it
existing before hand or not.
  EOT

  example api: <<-EOT
Register a machine before you boot it, and note that it already has an OS
installed, so should not be subject to policy-based reinstallation:

    {
      "hw_info": {
        "net0":   "78:31:c1:be:c8:00",
        "net1":   "72:00:01:f2:13:f0",
        "net2":   "72:00:01:f2:13:f1",
        "serial": "xxxxxxxxxxx",
        "asset":  "Asset-1234567890",
        "uuid":   "Not Settable"
      },
      "installed": true
    }

  EOT

  example cli: <<-EOT
Register a machine before you boot it, and note that it already has an OS
installed, so should not be subject to policy-based reinstallation:

    razor register-node --hw-info net0=78:31:c1:be:c8:00 \\
        --hw-info net1=72:00:01:f2:13:f0 \\
        --hw-info net2=72:00:01:f2:13:f1 \\
        --hw-info serial=xxxxxxxxxxx \\
        --hw-info asset=Asset-1234567890 \\
        --hw-info uuid="Not Settable" \\
        --installed
  EOT

  authz  true

  attr   'installed', type: :bool, required: true, help: _(<<-HELP)
    Should the node be considered 'installed' already?  Installed nodes are
    not eligible for policy matching, and will simply boot locally.
  HELP

  object 'hw_info', required: true, size: 1..Float::INFINITY, help: _(<<-HELP) do
    The hardware information for the node.  This is used to match the node on first
    boot with the record in the database.  The order of MAC address assignment in
    this data is not significant, as a node with reordered MAC addresses will be
    treated as the same node.
  HELP
    extra_attrs /^net[0-9]+$/, type: String

    attr 'serial', type: String, help: _('The DMI serial number of the node')
    attr 'asset',  type: String, help: _('The DMI asset tag of the node')
    attr 'uuid',   type: String, help: _('The DMI UUID of the node')
  end


  def run(request, data)
    Razor::Data::Node.lookup(data['hw_info']).set(installed: data['installed']).save.
        tap do |node|
      Razor::Data::Hook.trigger('node-registered', node: node)
    end
  end
end

