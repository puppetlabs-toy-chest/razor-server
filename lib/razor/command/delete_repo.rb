# -*- encoding: utf-8 -*-
class Razor::Command::DeleteRepo < Razor::Command
  summary "Delete a repo, removing any local files it downloaded"
  description <<-EOT
The repo, and any associated content on disk, will be removed.  This will fail
if the repo is in use with an existing policy.
  EOT

  example api: <<-EOT
Delete the "fedora16" repo:

    {"name": "fedora16"}
  EOT

  example cli: <<-EOT
Delete the "fedora16" repo:

    razor delete-repo --name fedora16

With positional arguments, this can be shortened::

    razor delete-repo fedora16
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250, position: 0,
        help: _('The name of the repo to delete.')

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
