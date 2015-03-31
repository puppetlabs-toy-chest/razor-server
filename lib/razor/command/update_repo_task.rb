# -*- encoding: utf-8 -*-

class Razor::Command::UpdateRepoTask < Razor::Command
  summary "Update the task associated to a repo"
  description <<-EOT
This ensures that the specified repo uses the specified task, setting it
if necessary. Note that if a node is currently provisioning against this
repo, provisioning errors may arise.
  EOT

  example api: <<-EOT
Update repo's task to a task named 'other_task':

    {"node": "node1", "repo": "my_repo", "task": "other_task"}
  EOT

  example cli: <<-EOT
Update repo's task to a task named 'other_task':

    razor update-repo-task --repo my_repo --task other_task
  EOT

  authz '%{repo}'

  attr 'repo', type: String, required: true, references: [Razor::Data::Repo, :name],
               help: _('The repo that will have its task updated.')

  attr 'task', type: String, required: true,
              help: _('The task to be used by the repo.')

  def run(request, data)
    repo = Razor::Data::Repo[:name => data['repo']]
    task_name = data['task']
    if repo.task_name != task_name
      repo.task_name = task_name
      repo.save

      { :result => _("repo %{name} updated to use task %{task}") %
          {name: data['repo'], task: data['task']} }
    else
      { :result => _("no changes; repo %{name} already uses task %{task}") %
          {name: data['repo'], task: data['task']} }
    end
  end
end
