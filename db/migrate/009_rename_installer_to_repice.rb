# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    # Alas, PostgreSQL, there is a lot of manual work.  At least you use
    # internal ID values to link these together, so we don't have to update,
    # eg, the column default value references when we rename sequences.
    rename_table :installers, :recipes
    %w{installers_name_index installers_name_key installers_pkey}.each do |from|
      to = from.sub('installers', 'recipes')
      self << "ALTER INDEX #{from} RENAME TO #{to}"
    end
    self << "ALTER SEQUENCE installers_id_seq RENAME TO recipes_id_seq"

    self[:sequel_constraint_validations].
      where(:table  => 'installers').
      update(:table => 'recipes')

    rename_column :policies, :installer_name, :recipe_name
  end

  down do
    rename_table :recipes, :installers
    %w{installers_name_index installers_name_key installers_pkey}.each do |to|
      from = from.sub('installers', 'recipes')
      self << "ALTER INDEX #{from} RENAME TO #{to}"
    end
    self << "ALTER SEQUENCE recipes_id_seq RENAME TO installers_id_seq"

    self.sequel_constraint_validations.
      where(:table  => 'recipes').
      update(:table => 'installers')

    rename_column :policies, :recipe_name, :installer_name
  end
end
