# -*- encoding: utf-8 -*-
require_relative './util'

# Node names were previously fabricated in application code as required; this
# resulted in a highly non-uniform API, and complicates validation code based
# on object references.
#
# This performs the same realization of the value into the database for
# existing nodes, and allows us to generate the appropriate value in
# the future.
Sequel.migration do
  up do
    extension(:constraint_validations)

    # We have to allow null values, because we have no initial setting, and
    # PostgreSQL does not allow deferring null value constraints in versions
    # that we support.  This is fixed later.
    add_column :nodes, :name, :varchar, :size => 250, :null => true

    from(:nodes).update(:name => Sequel.lit("'node' || id"))

    # Finally, declare it to be not null, now we have a value everywhere
    alter_table :nodes do
      set_column_not_null :name
      validate { format NAME_RX, :name, name: 'node_name_is_simple', allow_nil: true }
    end

    # ...and now the ugly part: we can't have a standard default value for the
    # node name, since we use "node${id}", and we can't reference a column in
    # a default value.
    #
    # The same restriction means that we can't just calculate it in the
    # application code before create, since we can't generate the name without
    # knowing the ID, and the ID is assigned at insert time by the database.
    #
    # So... this.  Sorry.
    run <<'SQL'
create or replace function nodes_node_name_default_trigger() returns trigger as $$
begin
    if NEW.name is NULL then
        NEW.name = 'node' || NEW.id;
    end if;
    return NEW;
end
$$ LANGUAGE plpgsql
SQL

    run <<'SQL'
create trigger nodes_node_name_default_trigger
before insert on nodes
for each row
execute procedure nodes_node_name_default_trigger()
SQL
  end

  down do
    run 'drop trigger nodes_node_name_default_trigger on nodes'
    run 'drop function nodes_node_name_default_trigger()'
    drop_column :nodes, :name
  end
end
