# -*- encoding: utf-8 -*-
class Razor::Command::RefreshRepo < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true

  def run(request, data)
    if repo = Razor::Data::Repo[:name => data['name']]
      repo.refresh(@command)
      action = _("repo refresh started")
    else
      action = _("no changes; repo %{name} does not exist") % {name: data["name"]}
    end
    { :result => action }
  end
end
