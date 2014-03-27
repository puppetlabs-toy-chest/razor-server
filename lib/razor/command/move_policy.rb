# -*- encoding: utf-8 -*-

class Razor::Command::MovePolicy < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Policy
  attr  'before'
  attr  'after'

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]

    position = nil
    neighbor = nil
    if data["before"] or data["after"]
      not data.key?("before") or not data.key?("after") or
        # TRANSLATORS: 'before' and 'after' should not be translated.
        request.error 400, :error => _("Only specify one of 'before' or 'after'")
      position = data["before"] ? "before" : "after"
      name = data[position]["name"] or
        request.error 400,
          :error => _("The policy reference in '%{position}' must have a name") % {position: position}
      neighbor = Razor::Data::Policy[:name => name] or
        request.error 400,
      :error => _("Policy '%{name}' referenced in '%{position}' not found") % {name: name, position: position}
    else
      # TRANSLATORS: 'before' and 'after' should not be translated.
      request.error 400, :error => _("You must specify either 'before' or 'after'")
    end

    policy.move(position, neighbor) if position
    policy.save

    policy
  end
end
