# -*- encoding: utf-8 -*-

class Razor::Command::MovePolicy < Razor::Command
  summary "Change the order that policies are considered when matching against nodes"
  description <<-EOT
Policies can be moved before or after specific policies.
  EOT

  example <<-EOT
Move a policy before another policy:

    {"name": "policy", "before": "other"}

Move a policy after another policy:

    {"name": "policy", "after": "other"}
  EOT


  authz '%{name}'
  attr   'name', type: String, required: true, references: Razor::Data::Policy

  require_one_of 'before', 'after'

  object 'before', exclude: 'after' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  object 'after', exclude: 'before' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    position = data["before"] ? "before" : "after"
    name = data[position]["name"]
    neighbor = Razor::Data::Policy[:name => name]

    policy.move(position, neighbor)
    policy.save

    policy
  end

  def self.conform!(data)
    data.tap do |_|
      data['before'] = { 'name' => data['before'] } if data['before'].is_a?(String)
      data['after'] = { 'name' => data['after'] } if data['after'].is_a?(String)
    end
  end
end
