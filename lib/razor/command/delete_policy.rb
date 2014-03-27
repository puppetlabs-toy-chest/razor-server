# -*- encoding: utf-8 -*-
class Razor::Command::DeletePolicy < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true

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
