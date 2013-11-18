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
      add_constraint    :node_policy_and_bound_is_true,
        "(policy_id is null OR bound)"
    end

  end

  down do
    alter_table :nodes do
      drop_column   :bound
    end
  end

end
