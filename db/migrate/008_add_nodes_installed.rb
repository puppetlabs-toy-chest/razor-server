# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    alter_table :nodes do
      # The name of the policy that was used to install this node, or NULL
      # if the node has not been successfully installed yet
      add_column        :installed, :varchar, :size => 250
      add_column        :installed_at, 'timestamp with time zone'

      add_constraint :nodes_installed_fields_set_together,
          "(installed is null and installed_at is null)
        or (installed is not null and installed_at is not null)"
    end

    # We assume that all nodes with a policy bound to them are actually
    # installed. Obviously, we lie about the 'installed_at' time.
    from(:nodes).exclude(:policy_id => nil).
      update(:installed => from(:policies).
                           where(:id => :policy_id).
                           select(:name),
             :installed_at => :now.sql_function)
  end

  down do
    alter_table :nodes do
      drop_column   :installed
      drop_colum    :installed_at
    end
  end

end
