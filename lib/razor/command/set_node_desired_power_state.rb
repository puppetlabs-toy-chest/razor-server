# -*- encoding: utf-8 -*-

class Razor::Command::SetNodeDesiredPowerState < Razor::Command
  summary "Sets the desired IPMI power state for a node."
  description <<-EOT
In addition to monitoring power, Razor can enforce node power state.
This command allows a desired power state to be set for a node. If the
node is observed to be in a different power state, an IPMI command is
issued to change to the desired state.
  EOT

  example <<-EOT
To set the power state for the node:

    {
      "name": "node1234",
      "to":   "on"|"off"|null
    }
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true,  references: Razor::Data::Node,
                help: _('The node for which to change the desired power state.')

  attr 'to', type: String, required: false, one_of: ['on', 'off', nil],
             help: _('The desired power state -- on, or off.')

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.set(desired_power_state: data['to']).save
    {result: _("Set desired power state to %{state}.") % {state: data['to'] || 'ignored (null)'}}
  end

  def self.conform!(data)
    data.tap do |_|
      data.delete('to') if data['to'].nil?
    end
  end
end
