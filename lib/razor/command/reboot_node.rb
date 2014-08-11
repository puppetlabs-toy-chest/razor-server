# -*- encoding: utf-8 -*-

class Razor::Command::RebootNode < Razor::Command
  summary "Requests an IPMI power cycle of a node."
  description <<-EOT
Razor can request a node reboot through IPMI, if the node has IPMI credentials
associated.  This command only supports hard power cycle reboots.

This command is applied in the background, and will run as soon as execution
slots are available for the task -- IPMI communication has some generous
internal rate limits to prevent it from overwhelming the network or host server.

This background process is persistent. If you restart the Razor server before
the command is executed, it will remain in the queue and the operation will
take place after the server restarts.  There is no time limit on how long this command will remain in your queue at
this time.

You can queue multiple commands. They will be processed sequentially, with
no limitation on how frequently a node can be rebooted.

If the IPMI request fails -- ipmitool reports it is unable to
communicate with the node -- the request will be retried.  The results of the reboot attempt aren't provided, so you might not know if the command is
delivered and fails to reboot the system. Eventually, an entry in the node's log will show the timestamp and event (boot), when it the node boots successfully. The time it takes to appear in the log can vary.

This command is not integrated with the IPMI power state monitoring, and you might not
see power transitions in the record, or through the node object if you're polling.
  EOT

  example <<-EOT
Queue a node reboot:

    {"name": "node1"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node,
                help: _('The name of the node to reboot.')

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.ipmi_hostname or
      request.error 422, { :error => _("Node %{name} does not have IPMI credentials set.") % {name: node.name} }

    node.publish 'reboot!'

    { :result => _('Reboot request queued.') }
  end
end
