# -*- encoding: utf-8 -*-

class Razor::Command::DisablePolicy < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    policy.set(enabled: false).save
    {:result => _("Policy %{name} disabled") % {name: policy.name}}
  end
end
