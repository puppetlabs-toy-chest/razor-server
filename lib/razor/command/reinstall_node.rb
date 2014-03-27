# -*- encoding: utf-8 -*-

class Razor::Command::ReinstallNode < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node

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
