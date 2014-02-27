# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)
      alter_table :policies do
        add_column :node_metadata, String
      end
  end

  down do
    alter_table :policies do
      drop_column :node_metadata
    end
  end
end
