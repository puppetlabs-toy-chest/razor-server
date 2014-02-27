# -*- encoding: utf-8 -*-
Sequel.migration do
  up do
    extension(:constraint_validations)
    create_constraint_validations_table
  end

  down do
    extension(:constraint_validations)
    drop_constraint_validations_table
  end
end
