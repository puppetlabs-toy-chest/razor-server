# -*- encoding: utf-8 -*-

class Razor::Command::MovePolicy < Razor::Command
  summary "Change the order that policies are considered when matching against nodes"
  description <<-EOT
Policies can be moved before or after specific policies.
  EOT

  example api: <<-EOT
Move a policy before another policy:

    {"name": "policy", "before": "other"}

Move a policy after another policy:

    {"name": "policy", "after": "other"}
  EOT

  example cli: <<-EOT
Move a policy before another policy:

    razor move-policy --name policy --before other

Move a policy after another policy:

    razor move-policy --name policy --after other

With positional arguments, this can be shortened::

    razor move-policy policy --after other
  EOT

  authz '%{name}'
  attr   'name', type: String, required: true, references: Razor::Data::Policy,
                 position: 0, help: _('The name of the policy to move.')

  require_one_of 'before', 'after'

  attr 'before', type: String, exclude: 'after', references: Razor::Data::Policy, help: _(<<-HELP)
    The name of the policy to move this policy before.
  HELP

  attr 'after', type: String, exclude: 'before', references: Razor::Data::Policy, help: _(<<-HELP)
    The name of the policy to move this policy after.
  HELP

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    position = data["before"] ? "before" : "after"
    name = data[position]
    neighbor = Razor::Data::Policy[:name => name]

    policy.move(position, neighbor)
    policy.save

    policy
  end

  def self.conform!(data)
    data.tap do |_|
      data['before'] = data['before']['name'] if data['before'].is_a?(Hash) and data['before'].keys == ['name']
      data['after'] = data['after']['name'] if data['after'].is_a?(Hash) and data['after'].keys == ['name']
    end
  end
end
