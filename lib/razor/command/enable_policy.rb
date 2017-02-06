# -*- encoding: utf-8 -*-

class Razor::Command::EnablePolicy < Razor::Command
  summary "Enable a policy, allowing it to matching new nodes"
  description <<-EOT
When a policy is disabled it will no longer match new nodes.  This command
will reverse the effect of disabling the policy, allowing it to match new
nodes again.  This does not cause nodes to be matched against the policy until
the next time they check in.
  EOT

  example api: <<-EOT
Enable a policy:

    {"name": "example"}
  EOT

  example cli: <<-EOT
Enable a policy:

    razor enable-policy --name example

With positional arguments, this can be shortened::

    razor enable-policy example
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy,
                position: 0, help: _('The name of the policy to enable.')

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    policy.set(enabled: true).save
    {:result => _("Policy %{name} enabled") % {name: policy.name}}
  end
end
