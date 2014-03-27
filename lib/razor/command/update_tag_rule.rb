# -*- encoding: utf-8 -*-

class Razor::Command::UpdateTagRule < Razor::Command
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
