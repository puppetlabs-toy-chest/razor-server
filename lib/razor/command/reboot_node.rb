# -*- encoding: utf-8 -*-

class Razor::Command::RebootNode < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.ipmi_hostname or
      request.error 422, { :error => _("node %{name} does not have IPMI credentials set") % {name: node.name} }

    node.publish 'reboot!'

    { :result => _('reboot request queued') }
  end
end
