# -*- encoding: utf-8 -*-

class Razor::Command::UpdatePolicyRepo < Razor::Command
  summary "Update the repo associated to a policy"
  description <<-EOT
This ensures that the specified policy uses the specified repo. Note that if a
node is currently provisioning against this policy, provisioning errors may
arise.
  EOT

  example api: <<-EOT
Update policy's repo to a repo named 'other_repo':

    {"policy": "my_policy", "repo": "other_repo"}
  EOT

  example cli: <<-EOT
Update policy's repo to a repo named 'other_repo':

    razor update-policy-repo --policy my_policy --repo other_repo

With positional arguments, this can be shortened:

    razor update-policy-repo my_policy other_repo
  EOT

  authz '%{policy}'

  attr 'policy', type: String, required: true, references: [Razor::Data::Policy, :name],
                 position: 0, help: _('The policy that will have its repo updated.')

  attr 'repo', type: String, required: true, position: 1,
               references: [Razor::Data::Repo, :name],
               help: _('The repo to be used by the policy.')

  def run(_, data)
    policy = Razor::Data::Policy[:name => data['policy']]
    repo = Razor::Data::Repo[:name => data['repo']]
    repo_name = data['repo']
    if policy.repo.name != repo_name
      policy.repo = repo
      policy.save

      { :result => _("policy %{name} updated to use repo %{repo}") %
          {name: data['policy'], repo: data['repo']} }
    else
      { :result => _("no changes; policy %{name} already uses repo %{repo}") %
          {name: data['policy'], repo: data['repo']} }
    end
  end
end
