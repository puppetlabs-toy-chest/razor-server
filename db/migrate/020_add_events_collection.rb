# -*- encoding: utf-8 -*-
require_relative './util'

# Razor needs to track several additional events in a log.
# The current table, 'node_log_entries' only tracks events
# relevant to nodes. This migration creates a more generic
# logging mechanism to capture all sorts of events. It then
# transfers the data from 'node_log_entries' and drops
# that table.
Sequel.migration do
  up do
    extension(:constraint_validations)

    # A table for events on the server.
    create_table :events do
      primary_key :id
      # The event could link all sorts of entities.
      foreign_key :broker_id, :brokers, :null => true, :on_delete => :set_null
      foreign_key :node_id, :nodes, :null => true, :on_delete => :set_null
      foreign_key :policy_id, :policies, :null => true, :on_delete => :set_null
      foreign_key :repo_id, :repos, :null => true, :on_delete => :set_null
      foreign_key :command_id, :commands, :null => true, :on_delete => :set_null
      String      :task_name, :null => true
      String      :severity, :null => false, :default => 'info'
      column      :timestamp, 'timestamp with time zone',
                  :default => :now.sql_function
      String      :entry, :null => false
    end

    # Populate the table with the node_log_entries data.
    from(:node_log_entries).each do |log_entry|
      old_entry = JSON.parse(log_entry[:entry])
      entry = {:node_id => log_entry[:node_id], :entry => log_entry[:entry]}
      if old_entry.has_key?('broker') && broker = self[:brokers].where(:name => old_entry['broker']).first
        entry[:broker_id] = broker[:id]
      end
      entry.merge!({:task_name => old_entry['task']}) if old_entry.has_key?('task')
      if old_entry.has_key?('policy') && policy = self[:policies].where(:name => old_entry['policy']).first
        entry[:policy_id] = policy[:id]
      end
      if old_entry.has_key?('repo') && repo = self[:repos].where(:name => old_entry['repo']).first
        entry[:repo_id] = repo[:id]
      end
      entry[:timestamp] = log_entry[:timestamp]
      entry[:severity] = JSON.parse(log_entry[:entry])['severity']
      from(:events).insert(entry)
    end

    # This table is now redundant.
    drop_table :node_log_entries
  end

  down do
    extension(:constraint_validations)
    drop_constraint_validations_for :table => :events
    # Re-create the node_log_entries table.
    create_table :node_log_entries do
      foreign_key :node_id, :nodes, :null => false, :on_delete => :cascade
      column      :timestamp, 'timestamp with time zone',
                  :default => :now.sql_function
      String      :entry, :null => false
    end

    # Populate the table with the events data.
    from(:events).
        each do |log_entry|
      log_entry[:entry]['severity'] = log_entry[:severity] if log_entry.has_key?(:severity)
      from(:node_log_entries).insert(:node_id => log_entry[:node_id], :entry => log_entry[:entry],
                                     :timestamp => log_entry[:timestamp])
    end

    drop_table :events
  end
end
