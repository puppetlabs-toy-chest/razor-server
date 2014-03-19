# -*- encoding: utf-8 -*-
require_relative './util'

# Sequel validation is done using the database, so the definitions for task name
# need to be updated. This change is needed on both the table itself and the
# constraint validations table.
Sequel.migration do
  task_name_rx = %r'\A[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\u0024](?:[^\u0000-\u001f\u0024]*[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\u0024])?\Z(?!\n)'i
  up do
    extension(:constraint_validations)

    alter_table :tasks do
      validate do
        # Separating drop and create due to limitation in Sequel.
        drop :installer_name_is_simple
      end
    end
    alter_table :tasks do
      validate do
        format task_name_rx, :name, :name => 'installer_name_is_simple'
      end
    end
  end

  down do
    extension(:constraint_validations)

    alter_table :tasks do
      validate do
        drop :installer_name_is_simple
      end
    end
    alter_table :tasks do
      validate do
        # Use old value.
        format NAME_RX, :name, :name => 'installer_name_is_simple'
      end
    end
  end
end
