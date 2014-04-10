# -*- encoding: utf-8 -*-
class Razor::Command::DeleteRepo < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250

  def run(request, data)
    if repo = Razor::Data::Repo[:name => data['name']]
      repo.destroy
      action = _("repo destroyed")
    else
      action = _("no changes; repo %{name} does not exist") % {name: data["name"]}
    end
    { :result => action }
  end
end
