# -*- encoding: utf-8 -*-

class Razor::Command::DisablePolicy < Razor::Command
  summary "Disable a policy, preventing it from matching new nodes"
  description <<-EOT
When a policy is disabled it will no longer match new nodes.  Any existing
node matched to it will remain matched to it.  This does not cause nodes to
stop installing if that was triggered by matching this policy prior to the
disable command.
  EOT

  example <<-EOT
Disable a policy:

    {"name": "example"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy,
                help: _('The name of the policy to disable.')

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    policy.set(enabled: false).save
    {:result => _("Policy %{name} disabled") % {name: policy.name}}
  end
end
