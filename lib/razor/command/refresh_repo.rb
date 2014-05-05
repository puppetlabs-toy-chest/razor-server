# -*- encoding: utf-8 -*-
class Razor::Command::RefreshRepo < Razor::Command
  summary "Initiate a refresh of a repository from its source"
  description <<-EOT
Initiates a refresh of a repoisitory from its source.  This is done by removing
the repository from disk and replacing it with a fresh copy from the source.

This is also useful in cases where multiple razor servers are connected to
a single database.  Second and subsequent servers can use this command to
populate their own copies of repositories without having to define their own
in the database.

WARNING: This operation will cause an interuption in the repositories availability
and may impact dependant tasks in progress.
  EOT

  example <<-EOT
Refresh an existing repository:
  {
    repo: { 'name': 'myRepo' }
  }
  EOT

  authz '%{repo}'
  object 'repo',    required: true, help: _(<<-HELP) do
    The repository to trigger a refresh for.
  HELP
    attr 'name',    type: String, required: true, references: Razor::Data::Repo,
                    help: _('The name for the repository to trigger a refresh for.')
  end

  def run(request, data)
    repo = Razor::Data::Repo[:name => data['repo']['name']]
    repo.refresh(@command)
    { :result => "repo refresh started" }
  end

  def self.conform!(data)
    data.tap do |_|
      data['repo'] = { 'name' => data['repo'] } if data['repo'].is_a?(String)
    end
  end
end
