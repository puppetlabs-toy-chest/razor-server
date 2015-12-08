# -*- encoding: utf-8 -*-

class Razor::Command::DeleteHook < Razor::Command
  summary "Delete an existing hook configuration"
  description <<-EOT
Delete a hook configuration from Razor.  If the hook is currently used by
a policy the attempt will fail.
  EOT

  example api: <<-EOT
Delete the unused hook configuration "obsolete":

    {"name": "obsolete"}
  EOT

  example cli: <<-EOT
Delete the unused hook configuration "obsolete":

    razor delete-hook --name obsolete

With positional arguments, this can be shortened::

    razor delete-hook obsolete
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250, position: 0,
                help: _('The name of the hook to delete.')

  def run(request, data)
    if hook = Razor::Data::Hook[:name => data['name']]
      hook.destroy
      action = _("hook %{name} destroyed") % {name: data['name']}
    else
      action = _("no changes; hook %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end
end
