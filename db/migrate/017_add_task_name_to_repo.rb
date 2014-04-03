# -*- encoding: utf-8 -*-
require_relative './util'

# Add the `task_name` column as a mandatory link between `repo` and a task.
# After this, the existing link from `policy` to a task is no longer required,
# but still serves as an override on the policy level.
Sequel.migration do
  up do
    extension(:constraint_validations)

    add_column :repos, :task_name, String, :null => true

    from(:repos).update(:task_name => 'noop')

    alter_table(:repos) { set_column_not_null :task_name }

    alter_table(:policies) { set_column_allow_null :task_name }

    # If only one task exists for the repo (via policy), assign it to repo and remove it from policy.
    from(:policies).
        join(:repos, :id => :repo_id).
        select_group(:repos__id).
        having("count(*) = 1").
        each do |repo|
          task_name = from(:policies).select(:task_name).where(:repo_id => repo[:id])
          from(:repos).where(id: repo[:id]).update(:task_name => task_name)
          from(:policies).where(repo_id: repo[:id]).update(:task_name => nil)
        end

    # Warning if using repo's task 'noop' + override on policy.
    from(:policies).
        join(:repos, :id => :repo_id).
        select_group(:repos__id).
        having("count(*) > 1").
        each do |repo|
          repo_name = from(:repos).select(:name).where(:id => repo[:id]).single_value
          puts _("Warning: Multiple policies found for repo #{repo_name}; unable to control task from repo")
        end
  end

  down do
    # Move back to policy if policy is empty.
    from(:policies).exclude(:task_name => nil).each do |policy|
      puts "Policy #{policy[:name]} already has a task_name; not overriding"
    end
    from(:repos).each do |repo_iterator|
      from(:policies).
          where(repo_id: repo_iterator[:id], task_name: nil).
          update(:task_name => repo_iterator[:task_name])
    end
    alter_table(:repos) { drop_column :task_name }
    alter_table(:policies) { set_column_not_null :task_name }
  end
end
