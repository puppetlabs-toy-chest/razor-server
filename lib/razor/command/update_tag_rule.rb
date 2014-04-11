# -*- encoding: utf-8 -*-

class Razor::Command::UpdateTagRule < Razor::Command
  summary "Update the matching rule for an existing tag"
  description <<-EOT
This will change the rule of the given tag to the new rule. The tag will be
reevaluated against all nodes and each node's tag attribute will be updated to
reflect whether the tag now matches or not, i.e., the tag will be added
to/removed from each node's tag as appropriate.

If the tag is used by any policies, the update will only be performed if the
optional parameter `force` is set to `true`. Otherwise, it will fail.
  EOT

  example <<-EOT
An example of updating a tag rule, and forcing reevaluation:

    {
      "name": "small",
      "rule": ["<=", ["fact", "processorcount"], "2"],
      "force": true
    }
  EOT

  authz '%{name}'
  attr  'name',  type: String, required: true, references: Razor::Data::Tag
  attr  'rule',  type: Array
  attr  'force', type: :bool

  def run(request, data)
    tag = Razor::Data::Tag[:name => data["name"]]
    data["force"] or tag.policies.empty? or
      request.error 400, :error => _("Tag '%{name}' is used by policies and 'force' is false") % {name: data["name"]}
    if tag.rule != data["rule"]
      tag.rule = data["rule"]
      tag.save
      { :result => _("Tag %{name} updated") % {name: data["name"]} }
    else
      { :result => _("No change; new rule is the same as the existing rule for %{name}") % {name: data["name"]} }
    end
  end
end
