# -*- encoding: utf-8 -*-
class Razor::Command::DeleteNode < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true

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
