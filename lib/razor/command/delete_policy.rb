# -*- encoding: utf-8 -*-
class Razor::Command::DeletePolicy < Razor::Command
  summary "Delete a policy from Razor, so it no longer matches new nodes"
  description <<-EOT
Delete a single policy, removing it from Razor.  This will work regardless of
the number of nodes bound to that policy.  Any node that was installed will
remain "installed", and will not be matched to by other policy.
  EOT

  example <<-EOT
Delete the policy "obsolete":

    {"name": "obsolete"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the policy to delete.')

  def run(request, data)
    # deleting a policy will first remove the policy from any node associated
    # with it.  The node will remain bound, resulting in the noop task being
    # associated on boot (causing a local boot)
    if policy = Razor::Data::Policy[:name => data['name']]
      policy.remove_all_nodes
      policy.remove_all_tags
      policy.destroy
      action = _("policy destroyed")
    else
      action = _("no changes; policy %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end
end
