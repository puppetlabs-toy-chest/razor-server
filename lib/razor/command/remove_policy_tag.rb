# -*- encoding: utf-8 -*-

class Razor::Command::RemovePolicyTag < Razor::Command
  summary "Remove a tag from an existing policy"
  description <<-EOT
This will remove a tag already present from a policy.  This change has no
effect on nodes already bound to the policy.
  EOT

  example <<-EOT
Remove the tag `virtual` to the policy `example`:

    {"name": "example", "tag": "virtual"}
  EOT

  attr 'name', type: String, required: true, references: Razor::Data::Policy
  attr 'tag',  type: String, required: true, size: 1..Float::INFINITY

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    tag = Razor::Data::Tag[:name => data['tag']]

    if tag and policy.tags.include?(tag)
      policy.remove_tag(tag)
      policy
    else
      action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end
end
