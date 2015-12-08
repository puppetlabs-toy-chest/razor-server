# -*- encoding: utf-8 -*-

class Razor::Command::ModifyPolicyMaxCount < Razor::Command
  summary "Change the maximum node count for an existing policy"
  description <<-EOT
Adjust the maximum node count for a policy.  The new value must be equal to or
greater than the number of nodes currently bound to the policy; it may also be
`null` for an "unlimited" count of nodes bound.
  EOT

  example api: <<-EOT
Set a policy to match an unlimited number of nodes:

    {"name": "example", "no_max_count": true}

Set a policy to a maximum of 15 nodes:

    {"name": "example", "max_count": 15}
  EOT

  example cli: <<-EOT
Set a policy to match an unlimited number of nodes:

    razor modify-policy-max-count --name example --no-max-count

Set a policy to a maximum of 15 nodes:

    razor modify-policy-max-count --name example --max-count 15

With positional arguments, this can be shortened::

    razor modify-policy-max-count example 15
  EOT

  authz '%{name}'

  attr 'name', type: String, required: true, references: Razor::Data::Policy,
               position: 0, help: _('The name of the policy to modify.')

  attr 'max_count', position: 1, type: Integer, help: _(<<-HELP)
    The new maximum number of nodes bound by this policy. You cannot reduce the
    maximum number of nodes bound to a policy below the number of nodes
    currently bound to the policy with this command.

    To make the policy unbounded, use the `no_max_count` argument instead.
  HELP

  attr 'no_max_count', type: TrueClass, help: _(<<-HELP)
    Make the maximum number of nodes that can bind to this policy unlimited.
  HELP

  require_one_of 'max_count', 'no_max_count'

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]

    if data['no_max_count']
      max_count = nil
      bound = "unbounded"
    else
      bound = max_count = data['max_count']
      node_count = policy.nodes.count
      node_count <= max_count or
        request.error 400, :error => n_(
        "There is currently %{node_count} node bound to this policy. Cannot lower max_count to %{max_count}",
        "There are currently %{node_count} nodes bound to this policy. Cannot lower max_count to %{max_count}",
        node_count) % {node_count: node_count, max_count: max_count}
    end
    policy.set(max_count: max_count).save
    { :result => _("Changed max_count for policy %{name} to %{count}") % {name: policy.name, count: bound} }
  end
end
