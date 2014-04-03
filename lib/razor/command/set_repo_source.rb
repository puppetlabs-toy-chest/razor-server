# -*- encoding: utf-8 -*-
class Razor::Command::SetRepoSource < Razor::Command
  summary "Set the source for an existing repository"
  description <<-EOT
Set the source, being either an iso-url or url, on an exisiting repository.

By default the repository will start a refresh of its content from the new
location, but this can be defered and manually triggered at a later time with
the refresh-repo command.

WARNING: Refreshing the repository will cause an interuption in the repositories
availability and may impact dependant tasks in progress.
  EOT

  example <<-EOT
Set the source to be an iso-url:
  {
    repo: { name: 'myRepo' },
    iso-url: 'http://myserver.com/my_iso_file.iso'
  }

Set the source to a URL with the content already unpacked:
  {
    repo: { name: 'myRepo' },
    url: 'http://myserver.com/my_repo/'
  }

Defer the refresh to be done manually later:
  {
    repo: { name: 'myRepo' },
    url: 'http://myserver.com/my_repo/',
    refresh: false
  }
  EOT

  authz '%{repo}'

  object 'repo',    required: true, help: _(<<-HELP) do
    The repository to set the source for.
  HELP
    attr 'name',    type: String, required: true, references: Razor::Data::Repo,
                    help: _('The name for the repository to set the source for.')
  end
  attr   'url',     type: URI,    exclude: 'iso-url',
                    help: _('The url to use as the new source.  Cannot be used in conjunction with "iso-url"')
  attr   'iso-url', type: URI,    exclude: 'url',
                    help: _('The iso-url to use as the new source. Cannot be used in conjunction with "url"')
  attr   'refresh', type: :bool,
                    help: _('Control whether or not to trigger a refresh.  Accepts true/false, default: true')

  require_one_of 'url', 'iso-url'

  def run(request, data)
    repo = Razor::Data::Repo[:name => data['repo']['name']]
    data["iso_url"] = data.delete("iso-url")
    repo.set_source(@command, data)
  end
  
  def self.conform!(data)
    data.tap do |_|
      data['repo'] = { 'name' => data['repo'] } if data['repo'].is_a?(String)
    end
  end
end
