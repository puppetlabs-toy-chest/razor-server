# -*- encoding: utf-8 -*-

class Razor::Command::DeleteTag < Razor::Command
  authz '%{name}'
  attr  'name',  type: String, required: true
  attr  'force', type: :bool

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
