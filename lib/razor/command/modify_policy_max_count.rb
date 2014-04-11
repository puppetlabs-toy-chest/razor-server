# -*- encoding: utf-8 -*-

class Razor::Command::ModifyPolicyMaxCount < Razor::Command
  summary "Change the maximum node count for an existing policy"
  description <<-EOT
Adjust the maximum node count for a policy.  The new value must be equal to or
greater than the number of nodes currently bound to the policy; it may also be
`null` for an "unlimited" count of nodes bound.
  EOT

  example <<-EOT
Set a policy to match an unlimited number of nodes:

    {"name": "example", "max-count": null}

Set a policy to a maximum of 15 nodes:

    {"name": "example", "max-count": 15}
  EOT


  attr 'name',      type: String, required: true, references: Razor::Data::Policy
  attr 'max-count', required: true

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]

    max_count_s = data['max-count']

    if max_count_s.nil?
      max_count = nil
      bound = "unbounded"
    else
      max_count = max_count_s.to_i
      max_count.to_s == max_count_s.to_s or
        request.error 422, :error => _("New max-count '%{raw}' is not a valid integer") % {raw: max_count_s}
      bound = max_count_s
      node_count = policy.nodes.count
      node_count <= max_count or
        request.error 400, :error => n_(
        "There is currently %{node_count} node bound to this policy. Cannot lower max-count to %{max_count}",
        "There are currently %{node_count} nodes bound to this policy. Cannot lower max-count to %{max_count}",
        node_count) % {node_count: node_count, max_count: max_count}
    end
    policy.set(max_count: max_count).save
    { :result => _("Changed max-count for policy %{name} to %{count}") % {name: policy.name, count: bound} }
  end
end
