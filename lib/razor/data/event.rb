# -*- encoding: utf-8 -*-
module Razor::Data
  class Event < Sequel::Model
    plugin :serialization, :json, :entry
    many_to_one :node
    many_to_one :policy
    many_to_one :repo
    many_to_one :broker
    many_to_one :command
    many_to_one :hook
    # def_column_accessor 'task_name'


    # The 'name' of the event. Since this needs to be unique, we simply
    # use the id of the object
    def name
      # The name must be a string
      id.to_s
    end

    def task
      task_name ? Razor::Task.find(task_name) : nil
    rescue Razor::TaskNotFoundError
      nil
    end

    def self.log_append(entry)
      entry[:severity] ||= 'info'
      hook = entry.delete(:hook)
      hook = Hook[id: hook] unless hook.is_a?(Hook)
      node = entry.delete(:node)
      node = Node[id: node] unless node.is_a?(Node)
      policy = entry.delete(:policy)
      policy = Policy[id: policy] unless policy.is_a?(Policy)
      # Roundtrip the hash through JSON to make sure we always have the
      # same entries in the log that we would get from loading from DB
      # (otherwise we could have symbols, which will turn into strings on
      # reloading)
      entry = JSON::parse(entry.to_json)
      hash = {
          :entry => entry,
          :hook_id => hook.is_a?(Hook) && hook.exists? ? hook.id : nil,
          :node_id => node.is_a?(Node) && node.exists? ? node.id : nil,
          :policy_id => policy.is_a?(Policy) && policy.exists? ? policy.id : policy
      }.reject {|_, v| v.nil?}

      new(hash).save
    end
  end
end
