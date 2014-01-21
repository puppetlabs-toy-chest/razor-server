require_relative './util'

Sequel.migration do
  up do
    # Alas, PostgreSQL, there is a lot of manual work.  At least you use
    # internal ID values to link these together, so we don't have to update,
    # eg, the column default value references when we rename sequences.
    rename_table :recipes, :tasks
    %w{recipes_name_index recipes_name_key recipes_pkey}.each do |from|
      to = from.sub('recipes', 'tasks')
      self << "ALTER INDEX #{from} RENAME TO #{to}"
    end
    self << "ALTER SEQUENCE recipes_id_seq RENAME TO tasks_id_seq"

    self[:sequel_constraint_validations].
      where(:table  => 'recipes').
      update(:table => 'tasks')

    rename_column :policies, :recipe_name, :task_name
  end

  down do
    rename_table :tasks, :recipes
    %w{recipes_name_index recipes_name_key recipes_pkey}.each do |to|
      from = from.sub('recipes', 'tasks')
      self << "ALTER INDEX #{from} RENAME TO #{to}"
    end
    self << "ALTER SEQUENCE tasks_id_seq RENAME TO recipes_id_seq"

    self.sequel_constraint_validations.
      where(:table  => 'tasks').
      update(:table => 'recipes')

    rename_column :policies, :task_name, :recipe_name
  end
end
