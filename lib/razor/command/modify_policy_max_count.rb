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

    {"name": "example", "max_count": null}

Set a policy to a maximum of 15 nodes:

    {"name": "example", "max_count": 15}
  EOT

  example cli: <<-EOT
Set a policy to match an unlimited number of nodes:

    razor --name example --max-count null

Set a policy to a maximum of 15 nodes:

    razor --name example --max-count 15
  EOT

  authz '%{name}'

  attr 'name', type: String, required: true, references: Razor::Data::Policy,
               help: _('The name of the policy to modify.')

  attr 'max_count', required: true, help: _(<<-HELP)
    The new maximum number of nodes bound by this policy.  This can be
    "null", in which case the policy becomes unlimited, or an integer
    greater than or equal to one.

    You cannot reduce the maximum number of nodes bound to a policy below
    the number of nodes currently bound to the policy with this command.
  HELP

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]

    max_count_s = data['max_count']

    if max_count_s.nil?
      max_count = nil
      bound = "unbounded"
    else
      max_count = max_count_s.to_i
      max_count.to_s == max_count_s.to_s or
        request.error 422, :error => _("New max_count '%{raw}' is not a valid integer") % {raw: max_count_s}
      bound = max_count_s
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
