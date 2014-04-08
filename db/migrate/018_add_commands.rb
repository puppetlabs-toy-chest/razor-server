# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  COMMAND_NAME_RX = %r{\A[a-z-]*\Z}

  up do
    extension(:constraint_validations)

    run %q{CREATE TYPE command_status AS ENUM
             ('pending', 'running', 'failed', 'finished')}

    # A table for the commands that have been submitted to the server
    create_table :commands do
      primary_key :id
      # The command name - we can't use 'name' here since the assumption
      # that 'name' is unique is baked in all over the place.
      column      :command, :varchar, :size => 80, :null => false
      # JSON representation of the params
      String      :params, :default => '{}'
      # JSON representation of an array of error details or NULL; this will
      # be non-NULL if status is 'failed'. It can also contain information
      # about transient errors that we could recover from during background
      # processing
      #
      # We would really like to call this 'errors' since it's an array, but
      # that clashes with the naming conventions of Sequel::Model, which
      # uses 'errors' for validation errors. Hard CS problems and all
      String      :error
      column      :status, 'command_status', :null => false
      column      :submitted_at, 'timestamp with time zone', :null => false,
                                 :default => :now.sql_function
      String      :submitted_by
      column      :finished_at,  'timestamp with time zone'

      constraint :command_error_non_empty_if_failed, <<SQL
(status != 'failed' or error is not NULL)
SQL

      validate do
        format COMMAND_NAME_RX, :command, :name => 'command_name_is_legal'
      end
    end
  end

  down do
    extension(:constraint_validations)
    drop_constraint_validations_for :table => :commands
    drop_table :commands
    run %q{DROP TYPE command_status}
  end
end
