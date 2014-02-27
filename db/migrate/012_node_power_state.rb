# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    # Since an enum is ordered, this makes `on` > `off`.
    run %q{CREATE TYPE power_state AS ENUM ('off', 'on')}
    add_column :nodes, :desired_power_state, 'power_state', :null => true

    # This kind of hurts.
    rename_column :nodes, :last_known_power_state, :__last_known_power_state
    add_column :nodes, :last_known_power_state, 'power_state', :null => true
    from(:nodes).where(:__last_known_power_state => true).
      update(:last_known_power_state => 'on')
    from(:nodes).where(:__last_known_power_state => false).
      update(:last_known_power_state => 'off')
    drop_column :nodes, :__last_known_power_state
  end

  down do
    # Migrate back to the boolean version of the last power state column.
    rename_column :nodes, :last_known_power_state, :__last_known_power_state
    add_column :nodes, :last_known_power_state, :boolean, :null => true
    from(:nodes).where(:__last_known_power_state => 'on').
      update(:last_known_power_state => true)
    from(:nodes).where(:__last_known_power_state => 'off').
      update(:last_known_power_state => false)
    drop_column :nodes, :__last_known_power_state

    drop_column :nodes, :desired_power_state
    run %q{DROP TYPE power_state}
  end
end
