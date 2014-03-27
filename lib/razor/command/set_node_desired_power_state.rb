# -*- encoding: utf-8 -*-

class Razor::Command::SetNodeDesiredPowerState < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true,  references: Razor::Data::Node
  attr  'to',   type: [String, nil], required: false, one_of: ['on', 'off', nil]

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.set(desired_power_state: data['to']).save
    {result: _("set desired power state to %{state}") % {state: data['to'] || 'ignored (null)'}}
  end
end
