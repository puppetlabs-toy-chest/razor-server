# -*- encoding: utf-8 -*-

class Razor::Command::UpdatePolicyTask < Razor::Command
  summary "Update the task associated to a policy"
  description <<-EOT
This ensures that the specified policy uses the specified task, setting it
if necessary. Note that if a node is currently provisioning against this
policy, provisioning errors may arise.
  EOT

  example api: <<-EOT
Update policy's task to a task named 'other_task':

    {"policy": "my_policy", "task": "other_task"}

Use the task on the policy's repo:

    {"policy": "my_policy", "no_task": true}
  EOT

  example cli: <<-EOT
Update policy's task to a task named 'other_task':

    razor update-policy-task --policy my_policy --task other_task

Use the task on the policy's repo:

    razor update-policy-task --policy my_policy --no-task

With positional arguments, this can be shortened:

    razor update-policy-task my_policy other_task
  EOT

  authz '%{policy}'

  attr 'policy', type: String, required: true, references: [Razor::Data::Policy, :name],
                 position: 0, help: _('The policy that will have its task updated.')

  attr 'task', type: String, position: 1,
               help: _('The task to be used by the policy.')

  attr 'no_task', type: TrueClass, help: _('This policy should use the task on the repo')

  require_one_of 'task', 'no_task'

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['policy']]
    task_name = data['task']
    if policy.task_name != task_name
      policy.task_name = task_name
      policy.save

      { :result => _("policy %{name} updated to use task %{task}") %
          {name: data['policy'], task: data['task']} }
    else
      { :result => _("no changes; policy %{name} already uses task %{task}") %
          {name: data['policy'], task: data['task']} }
    end
  end
end
