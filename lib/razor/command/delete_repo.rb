# -*- encoding: utf-8 -*-
class Razor::Command::DeleteRepo < Razor::Command
  summary "Delete a repo, removing any local files it downloaded"
  description <<-EOT
The repo, and any associated content on disk, will be removed.  This will fail
if the repo is in use with an existing policy.
  EOT

  example <<-EOT
Delete the "fedora16" repo:

    {"name": "fedora16"}
  EOT

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
