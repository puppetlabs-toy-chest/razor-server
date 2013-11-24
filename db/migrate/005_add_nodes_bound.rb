require_relative './util'

Sequel.migration do
  up do
    alter_table :nodes do
      add_column        :bound, FalseClass, :default => false, :null => false
    end

    #For this migration, nodes with a policy should be set to bound.
    #This will be enforced on going by the constraint set in the next
    #alter_table
    from(:nodes).exclude(:policy_id => nil).update(:bound => true)

    alter_table :nodes do
      #If policy_id is set, bound must be true.  Can't have a policy and not be bound.
      #However, can be bound WITHOUT a policy.
      add_constraint  :node_policy_and_bound_is_true,
        "(policy_id is null OR bound)"

      drop_constraint :nodes_policy_sets_hostname
      drop_constraint :nodes_policy_sets_root_password
      add_constraint  :bound_sets_hostname,
        "(not bound OR hostname is not null)"
      add_constraint  :bound_sets_root_password,
        "(not bound OR root_password is not null)"
    end

  end

  down do
    alter_table :nodes do
      drop_constraint :bound_sets_hostname
      drop_constraint :bound_sets_root_password

      drop_column   :bound

      add_constraint  :nodes_policy_sets_hostname,
                  "policy_id is NULL or hostname is not NULL"
      add_constraint  :nodes_policy_sets_root_password,
                  "policy_id is NULL or root_password is not NULL"
    end
  end

end
