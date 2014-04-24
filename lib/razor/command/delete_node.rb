# -*- encoding: utf-8 -*-
class Razor::Command::DeleteNode < Razor::Command
  summary "Remove a single node from the database"
  description <<-EOT
Remove a single node from the database.  Should the node boot again it will be
rediscovered and treated as any other new node.
  EOT
  example <<-EOT
Delete the node "node17":

    {"name": "node17"}
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                help: _('the name of the node to delete')

  def run(request, data)
    if node = Razor::Data::Node[:name => data['name']]
      node.destroy
      action = _("node destroyed")
    else
      action = _("no changes; node %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end
end
