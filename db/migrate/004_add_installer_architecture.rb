# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :installers do
      add_column            :architecture, :varchar, :size => 16
    end
  end

  down do
    alter_table :installers do
      drop_column         :architecture
    end
  end
end
