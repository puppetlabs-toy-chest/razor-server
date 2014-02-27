# -*- encoding: utf-8 -*-
require_relative './util'

# Mark the unique constraint on policies.rule_number deferrable so we can
# move policies in the policy table up or down in bulk without tripping
# over the constraint. This makes it possible to treat policies as a list
# and insert into the list (or move policies around in that list) by
# renumbering policies just above the insertion point.
Sequel.migration do
  up do
    alter_table :policies do
      drop_constraint :policies_rule_number_key
      add_unique_constraint(:rule_number, :deferrable => true)
    end

    # Renumber policies so that rule_numbers are consecutive starting from 1
    index = 1
    self[:policies].order(:rule_number).all.each do |p|
      self[:policies].where(:id => p[:id]).update(:rule_number => index)
      index += 1
    end
  end

  down do
    alter_table :policies do
      drop_constraint :policies_rule_number_key
      add_unique_constraint(:rule_number)
    end
  end
end
