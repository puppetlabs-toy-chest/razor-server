# -*- encoding: utf-8 -*-

class Razor::Command::RunHook < Razor::Command
  summary "Run an existing hook"
  description <<-EOT
Run an existing hook for the supplied event with the entities referenced in
this command. This is useful if you are writing a hook script and want to test
that it works, or if an existing hook execution failed and you need to re-run
it. The hook execution will happen synchronously.
  EOT

  example api: <<-EOT
Run the hook 'counter' for the event 'node-booted' with the provided node.

    {
      "hook": "counter",
      "event": "node-booted",
      "node": "node1"
    }
  EOT

  example cli: <<-EOT
Run the hook 'counter' for the event 'node-booted' with the provided node.

    razor run-hook --name counter --event node-booted --node node1

With positional arguments, this can be shortened::

    razor run-hook counter --event node-booted --node node1
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250, references: [Razor::Data::Hook, :name],
                position: 0, help: _('The name of the hook to run.')
  attr  'event', type: String, required: true,
                one_of: Razor::Data::Hook::AVAILABLE_EVENTS,
                help: _('The name of the hook to run.')

  attr  'node', type: String, required: true, references: [Razor::Data::Node, :name],
                help: _('The name of the node involved in the hook execution.')

  attr  'policy', type: String, references: [Razor::Data::Policy, :name],
                help: _('The name of the policy involved in the hook execution (if any).')

  attr 'debug', type: TrueClass, help: _('Whether to include debug information in the resulting event')

  def run(request, data)
    hook = Razor::Data::Hook[:name => data['name']]
    node = Razor::Data::Node[:name => data['node']] if data['node']
    policy = Razor::Data::Policy[:name => data['policy']] if data['policy']

    result = hook.run(data['event'], node: node, policy: policy, debug: data['debug'])
    result = {result: _("no event handler exists for hook %{name}") % {name: data['name']}} if result.nil?
    result
  end
end
