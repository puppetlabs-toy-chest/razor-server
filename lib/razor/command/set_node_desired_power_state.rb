# -*- encoding: utf-8 -*-

class Razor::Command::SetNodeDesiredPowerState < Razor::Command
  summary "Set the desired IPMI power state for a node"
  description <<-EOT
In addition to monitoring power, Razor can enforce node power state.
This command allows a desired power state to be set for a node, and if the
node is observed to be in a different power state an IPMI command will be
issued to change to the desired state.
  EOT

  example api: <<-EOT
Setting the power state for the node:

    {
      "name": "node1234",
      "to":   "on"|"off"|null
    }
  EOT

  example cli: <<-EOT
Setting the power state for the node:

    razor set-node-desired-power-state --name node1234 \\
        --to on|off|null

With positional arguments, this can be shortened::

    razor set-node-desired-power-state node1234 off
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true,  references: Razor::Data::Node,
                position: 0,
                help: _('The node for which to change the desired power state.')

  attr 'to', type: String, required: false, one_of: ['on', 'off', nil],
             position: 1, help: _('The desired power state -- on, or off.')

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    node.set(desired_power_state: data['to']).save
    {result: _("set desired power state to %{state}") % {state: data['to'] || 'ignored (null)'}}
  end

  def self.conform!(data)
    data.tap do |_|
      data.delete('to') if data['to'].nil?
    end
  end
end
