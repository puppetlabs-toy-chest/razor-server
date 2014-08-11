# -*- encoding: utf-8 -*-
class Razor::Command::DeleteNode < Razor::Command
  summary "Removes a single node from the database."
  description <<-EOT
Removes a single node from the database. If the node boots again, it will be
rediscovered and treated as any other new node.
  EOT
  example <<-EOT
To delete the node "node17":

    {"name": "node17"}
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                help: _('The name of the node to delete.')

  def run(request, data)
    if node = Razor::Data::Node[:name => data['name']]
      node.destroy
      action = _("Node destroyed.")
    else
      action = _("No changes; node %{name} does not exist.") % {name: data['name']}
    end
    { :result => action }
  end
end
