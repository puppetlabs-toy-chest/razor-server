# -*- encoding: utf-8 -*-

class Razor::Command::RebootNode < Razor::Command
  summary "Request an IPMI power cycle of a node"
  description <<-EOT
Razor can request a node reboot through IPMI, if the node has IPMI credentials
associated.  This only supports hard power cycle reboots.

This is applied in the background, and will run as soon as available execution
slots are available for the task -- IPMI communication has some generous
internal rate limits to prevent it overwhelming the network or host server.

This background process is persistent: if you restart the Razor server before
the command is executed, it will remain in the queue and the operation will
take place after the server restarts.  There is no time limit on this at
this time.

Multiple commands can be queued, and they will be processed sequentially, with
no limitation on how frequently a node can be rebooted.

If the IPMI request fails (that is: ipmitool reports it is unable to
communicate with the node) the request will be retried.  No detection of
actual results is included, though, so you may not know if the command is
delivered and fails to reboot the system.

This is not integrated with the IPMI power state monitoring, and you may not
see power transitions in the record, or through the node object if polling.
  EOT

  example <<-EOT
Queue a node reboot: `{"name": "node1"}`
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node,
                help: _('The name of the node to reboot.')

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.ipmi_hostname or
      request.error 422, { :error => _("node %{name} does not have IPMI credentials set") % {name: node.name} }

    node.publish 'reboot!'

    { :result => _('reboot request queued') }
  end
end
