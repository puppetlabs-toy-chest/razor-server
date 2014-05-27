# -*- encoding: utf-8 -*-

class Razor::Command::DeleteTag < Razor::Command
  summary "Delete a tag"
  description <<-EOT
The tag will be deleted if it is not used, or if the `force` flag is true.

If `force` is true, the tag will be removed from all policies that use it
before being deleted.
  EOT

  example <<-EOT
Delete a tag, but only if it is not used:

    {"name": "example"}
    {"name": "example", "force": false}

Delete a tag regardless of it being used:

    {"name": "example", "force": true}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the tag to delete.')

  attr 'force', type: :bool, help: _(<<-HELP)
    If the tag is already in use, by default it will not be deleted.

    To make that work, the force option can be supplied, which will cause the
    tag to be removed from all nodes it is applied to and all policies which
    reference it before being deleted as a single, atomic action.
  HELP

  def run(request, data)
    if tag = Razor::Data::Tag[:name => data["name"]]
      data["force"] or tag.policies.empty? or
        request.error 400, :error => _("Tag '%{name}' is used by policies and 'force' is false") % {name: data["name"]}
      tag.remove_all_policies
      tag.remove_all_nodes
      tag.destroy
      { :result => _("Tag %{name} deleted") % {name: data["name"]} }
    else
      { :result => _("No change. Tag %{name} does not exist.") % {name: data["name"]} }
    end
  end
end
