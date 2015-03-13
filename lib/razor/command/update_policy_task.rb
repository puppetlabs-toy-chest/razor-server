# -*- encoding: utf-8 -*-

class Razor::Command::UpdatePolicyTask < Razor::Command
  summary "Update the task associated to a policy"
  description <<-EOT
This ensures that the specified policy uses the specified task, setting it
if necessary. Note that if a node is currently provisioning against this
policy, errors may arise.
  EOT

  example api: <<-EOT
Update policy's task to a task named 'other_task':

    {"node": "node1", "policy": "my_policy", "task": "other_task"}
  EOT

  example cli: <<-EOT
Update policy's task to a task named 'other_task':

    razor update-policy-task --policy my_policy --task other_task
  EOT

  authz '%{policy}'

  attr 'policy', type: String, required: true, references: [Razor::Data::Policy, :name],
               help: _('The policy that will have its task updated.')

  attr 'task', type: String, required: true,
              help: _('The task to be used by the policy.')

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
