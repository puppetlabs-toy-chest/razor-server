require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :nodes do
      add_column :metadata, String, :null => false, :default => '{}'
    end

    alter_table :policies do
      add_column :node_metadata, String
    end
  end

  down do
      alter_table :nodes do
        drop_column :metadata
      end

      alter_table :policies do
        drop_column :node_metadata
      end
  end
end
