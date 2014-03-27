# -*- encoding: utf-8 -*-

class Razor::Command::EnablePolicy < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    policy.set(enabled: true).save
    {:result => _("Policy %{name} enabled") % {name: policy.name}}
  end
end
