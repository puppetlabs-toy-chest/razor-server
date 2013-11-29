require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    # Join table for nodes/tags; we can't use create_join_table since we
    # want the association to disappear if either end disappears
    create_table :policies_nodes do
      foreign_key :policy_id, :policies, :null=>false, :on_delete => :cascade
      foreign_key :node_id, :nodes, :null=>false, :on_delete => :cascade
      primary_key [:policy_id, :node_id]
      index [:policy_id, :node_id]
    end
  end

  down do
    drop_table :policies_nodes
  end
end
