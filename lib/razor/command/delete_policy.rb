# -*- encoding: utf-8 -*-
class Razor::Command::DeletePolicy < Razor::Command
  summary "Deletes a policy from Razor so that it no longer matches new nodes."
  description <<-EOT
Deletes a single policy, removing it from Razor.  This will work regardless of
the number of nodes bound to that policy.  Any node that has already been installed will
remain "installed", and will not be matched to by another policy.
  EOT

  example <<-EOT
To delete the policy so that it is "obsolete":

    {"name": "obsolete"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the policy to delete.')

  def run(request, data)
    # Deleting a policy first removes the policy from any node associated
    # with it.  The node will remain bound, resulting in the noop task being
    # associated on boot (causing a local boot).
    if policy = Razor::Data::Policy[:name => data['name']]
      policy.remove_all_nodes
      policy.remove_all_tags
      policy.destroy
      action = _("Policy destroyed.")
    else
      action = _("No changes; policy %{name} does not exist.") % {name: data['name']}
    end
    { :result => action }
  end
end
