require_relative './util'

Sequel.migration do
  up do
    alter_table :nodes do
      add_column    :bound, FalseClass, :default => false, :null => false
    end

    #For this migration, nodes with a policy should be set to bound.
    from(:nodes).exclude(:policy_id => nil).update(:bound => true)
  end

  down do
    alter_table :nodes do
      drop_column   :bound
    end
  end

end
