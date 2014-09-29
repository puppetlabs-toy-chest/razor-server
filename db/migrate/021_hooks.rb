# -*- encoding: utf-8 -*-
require_relative './util'

# This creates the base schema for the hook class.
Sequel.migration do
  # Same as NAME_RX
  hook_name_rx = %r'\A[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000](?:[^\u0000-\u001f/]*[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000])?\Z(?!\n)'i

  up do
    extension(:constraint_validations)

    run %q{CREATE TYPE hook_events AS ENUM ('node_registered', 'node_bound',
                                     'node_reinstall', 'node_deleted')}

    create_table :hooks do
      primary_key :id
      column      :name, :varchar, :size => 250, :null => false
      index       Sequel.function(:lower, :name),
                  :unique => true, :name => 'hooks_name_index'

      # Tie our in-database version to the on-disk hook...
      column      :hook_type, :varchar, :size => 250, :null => false

      # JSON hash of configuration key/value pairs supplied by the user.
      # We don't really need the full weight of JSON, but better compatible
      # with the rest of the system and less surprising than efficient.
      column :configuration, :text, :null => false, :default => '{}'

      validate do
        format hook_name_rx, :name,        :name => 'hook_name_is_simple'
        format hook_name_rx, :hook_type, :name => 'hook_type_is_simple'
      end
    end

    alter_table :events do
      add_foreign_key :hook_id, :hooks, :null => true, :on_delete => :set_null
    end
  end

  down do
    extension(:constraint_validations)

    alter_table :events do
      drop_column :hook_id
    end

    drop_table :hooks
    run %q{DROP TYPE hook_events}
  end
end
