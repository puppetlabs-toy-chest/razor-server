# -*- encoding: utf-8 -*-

class Razor::Command::ReinstallNode < Razor::Command
  summary "Remove any policy associated with a node, and make it available for reinstallation"
  description <<-EOT
Remove a node's association with any policy and clears its `installed` flag;
once the node reboots, it will boot back into the Microkernel and go through
discovery, tag matching and possibly be bound to another policy. This command
does not change its metadata or facts.

To skip the Microkernel boot and policy-binding step, use the `same-policy`
attribute to simply clear the install flag.
  EOT

  example api: <<-EOT
Make 'node17' available for reinstallation:

    { "name": "node17" }

Reinstall 'node17' using its same policy:

    { "name": "node17", "same_policy": true }
  EOT

  example cli: <<-EOT
Make 'node17' available for reinstallation:

    razor reinstall-node --name node17

Reinstall 'node17' using its same policy:

    razor reinstall-node --name node17 --same-policy

With positional arguments, this can be shortened::

    razor reinstall-node node17 --same-policy
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node,
                position: 0,
                help: _('The name of the node to flag for reinstallation.')

  attr  'same_policy', type: :bool, help: _('Keep the same policy for the node.')

  def run(request, data)
    data['same_policy'] ||= false
    actions = []

    node = Razor::Data::Node[:name => data['name']]
    log = { :event => :reinstall }

    if node.policy and not data['same_policy']
      log[:policy_name] = node.policy.name
      node.unbind
      actions << _("node unbound from %{policy}") % {policy: log[:policy_name]}
    end

    if node.installed
      log[:installed] = node.installed
      node.installed = nil
      node.installed_at = nil
      node.boot_count = 1
      actions << _("installed flag cleared")
    end

    if actions.empty?
      actions << _("no changes; node %{name} was neither bound nor installed") % {name: data['name']}
    end

    node.log_append(log)
    node.save

    # @todo danielp 2014-02-27: I don't know the best way to handle this sort
    # of conjoined string in translation.
    { :result => actions.join(_(" and ")) }
  end
end
