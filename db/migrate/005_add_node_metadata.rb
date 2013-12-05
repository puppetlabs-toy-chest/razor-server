require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :nodes do
      add_column :metadata, String, :null => false, :default => '{}'
    end
  end

  down do
      alter_table :nodes do
        drop_column :metadata
      end
  end
end
