# -*- encoding: utf-8 -*-

class Razor::Command::EnablePolicy < Razor::Command
  summary "Enable a policy, allowing it to matching new nodes"
  description <<-EOT
When a policy is disabled it will no longer match new nodes.  This command
will reverse the effect of disabling the policy, allowing it to match new
nodes again.  This does not cause nodes to be matched against the policy until
the next time they check in.
  EOT

  example <<-EOT
Enable a policy:

    {"name": "example"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    policy.set(enabled: true).save
    {:result => _("Policy %{name} enabled") % {name: policy.name}}
  end
end
