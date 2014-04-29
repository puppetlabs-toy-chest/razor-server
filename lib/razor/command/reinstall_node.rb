# -*- encoding: utf-8 -*-

class Razor::Command::ReinstallNode < Razor::Command
  summary "Remove any policy associated with a node, and make it available for reinstallation"
  description <<-EOT
Remove a node's association with any policy and clears its `installed` flag;
once the node reboots, it will boot back into the Microkernel and go through
discovery, tag matching and possibly be bound to another policy. This command
does not change its metadata or facts.
  EOT

  example <<-EOT
Make 'node17' available for reinstallation: `{"name": "node17"}`
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node,
                help: _('The name of the node to flag for reinstallation.')

  def run(request, data)
    actions = []

    node = Razor::Data::Node[:name => data['name']]
    log = { :event => :reinstall }

    if node.policy
      log[:policy_name] = node.policy.name
      node.policy = nil
      actions << _("node unbound from %{policy}") % {policy: log[:policy_name]}
    end

    if node.installed
      log[:installed] = node.installed
      node.installed = nil
      node.installed_at = nil
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
