require_relative './util'

# Mark the unique constraint on policies.rule_number deferrable so we can
# move policies in the policy table up or down in bulk without tripping
# over the constraint. This makes it possible to treat policies as a list
# and insert into the list (or move policies around in that list) by
# renumbering policies just above the insertion point.
Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :policies do
      drop_constraint :policies_name_key
      add_index  Sequel.function(:lower, :name), :unique => true, :name => 'policies_name_index'
      validate do
        format NAME_RX, :name,        :name => 'policy_name_is_simple'
      end
    end
  end

  down do
    # Not really worth bothering
  end
end
