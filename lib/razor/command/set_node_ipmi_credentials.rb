# -*- encoding: utf-8 -*-

class Razor::Command::SetNodeIPMICredentials < Razor::Command
  summary "Set the IPMI host, and credentials, for a node"
  description <<-EOT
Razor can store IPMI credentials on a per-node basis.  These are the hostname
(or IP address), the username, and the password to use when contacting the
BMC/LOM/IPMI lan or lanplus service to check or update power state and other
node data.

This is an atomic operation: all three data items are set or reset in a single
operation.  Partial updates must be handled client-side.  This eliminates
conflicting update and partial update combination surprises for users.

As with the IPMI authentication standard, both username and password are
optional, and the system will work with either or both absent.
  EOT

  example api: <<-EOT
Set IPMI credentials for node 'node17':

    {
      "name":          "node17",
      "ipmi_hostname": "bmc17.example.com",
      "ipmi_username": null,
      "ipmi_password": "sekretskwirrl"
    }
  EOT

  example cli: <<-EOT
Set IPMI credentials for node 'node17':

    razor set-node-ipmi-credentials --name node17 \\
        --ipmi-hostname bmc17.example.com \\
        --ipmi-username null \\
        --ipmi-password sekretskwirrl
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node,
                help: _('The node on which to set IPMI credentials.')

  attr 'ipmi_hostname', type: String, size: 1..255,
                        help: _('The IPMI hostname or IP address of the BMC of this host.')

  attr 'ipmi_username', type: String, also: 'ipmi_hostname', size: 1..32,
                        help: _('The IPMI LANPLUS username, if any, for this BMC.')

  attr 'ipmi_password', type: String, also: 'ipmi_hostname', size: 1..20,
                        help: _('The IPMI LANPLUS password, if any, for this BMC.')

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    # Finally, save the changes.  This is using the unrestricted update
    # method because we carefully manually constructed our input above,
    # effectively doing our own input validation manually.  If you ever
    # change that (because, say, we fix the -/_ thing globally, make sure
    # you restrict this to changing the specific attributes only.
    node.update(
      :ipmi_hostname => data['ipmi_hostname'],
      :ipmi_username => data['ipmi_username'],
      :ipmi_password => data['ipmi_password'])

    { :result => _('updated IPMI details') }
  end
end
