require_relative './util'

Sequel.migration do
  up do
    alter_table :nodes do
      add_column :desired_power_state, :boolean, :null => true
    end
  end

  down do
    alter_table :nodes do
      drop_column :desired_power_state
    end
  end
end
