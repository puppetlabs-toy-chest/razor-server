# -*- encoding: utf-8 -*-

class Razor::Command::MovePolicy < Razor::Command
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
end
