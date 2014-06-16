# -*- encoding: utf-8 -*-
class Razor::Command::DeleteRepo < Razor::Command
  summary "Deletes a repo, removing any local files it downloaded."
  description <<-EOT
The repo and any associated content on disk, will be removed.  DeleteRepo will fail
if the repo is in use with an existing policy.
  EOT

  example <<-EOT
To delete the "fedora16" repo:

    {"name": "fedora16"}
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
        help: _('The name of the repo to delete.')

  def run(request, data)
    if repo = Razor::Data::Repo[:name => data['name']]
      repo.destroy
      action = _("Repo destroyed.")
    else
      action = _("No changes; repo %{name} does not exist.") % {name: data["name"]}
    end
    { :result => action }
  end
end
