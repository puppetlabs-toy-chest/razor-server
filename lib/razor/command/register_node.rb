# -*- encoding: utf-8 -*-

class Razor::Command::RegisterNode < Razor::Command
  summary "Registers a node with Razor before it is discovered."
  description <<-EOT
In order to make it easier to deploy Razor on a network where some nodes already have operating systems installed,  we allow users to
register nodes explicitly. This command allows you to perform the same
registration that would happen when a new node checked in, ahead of time.

In order for nodes to register effectively, `hw_info` must contain enough information
that the node can successfully be matched during the iPXE boot phase.

If the node matches an existing node in keeping with the overall policy of
commands declaring desired state, the node's `installed` field will be updated to
match the value in this command.

Finally, a node with the supplied hardware information and the
desired installed state will be present in the database, regardless of whether it previously existed or not.
  EOT

  example <<-EOT
To register a machine before you boot it to let Razor know it already has an OS installed:

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

  authz  true

  attr   'installed', type: :bool, required: true, help: _(<<-HELP)
    Should the node be considered 'installed' already?  Installed nodes are
    not eligible for policy matching, and will simply boot locally.
  HELP

  object 'hw-info', required: true, size: 1..Float::INFINITY, help: _(<<-HELP) do
    The hardware information for the node.  This is used to match the node on first
    boot with the record in the database.  The order of MAC address assignment in
    this data is not significant, because a node with reordered MAC addresses will be
    treated as the same node.
  HELP
    extra_attrs /^net[0-9]+$/, type: String

    attr 'serial', type: String, help: _('The DMI serial number of the node.')
    attr 'asset',  type: String, help: _('The DMI asset tag of the node.')
    attr 'uuid',   type: String, help: _('The DMI UUID of the node.')
  end


  def run(request, data)
    Razor::Data::Node.lookup(data['hw-info']).set(installed: data['installed']).save
  end

  def self.conform!(data)
    data.tap { |_|
      data['hw-info'] = data.delete('hw_info') if data.has_key?('hw_info')
    }
  end
end

