require_relative './util'

Sequel.migration do
  up do
    create_table :node_messages do
      foreign_key :node_id, :nodes, :null => false, :on_delete => :cascade, :on_update => :cascade
      column      :timestamp, 'timestamp with time zone',
                  :default => :now.sql_function, :null => false, :primary_key => true
      String      :message, :null => false
    end
  end

  down do
    drop_table :node_messages
  end
end
