# -*- encoding: utf-8 -*-
module Razor::Data
  class Event < Sequel::Model
    plugin :serialization, :json, :entry
    many_to_one :node
    many_to_one :policy
    many_to_one :repo
    many_to_one :broker
    many_to_one :command
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
      node = entry.delete(:node)
      # Roundtrip the hash through JSON to make sure we always have the
      # same entries in the log that we would get from loading from DB
      # (otherwise we could have symbols, which will turn into strings on
      # reloading)
      entry = JSON::parse(entry.to_json)
      hash = {
          :entry => entry,
          :hook_id => hook ? hook.id : nil,
          :node_id => node ? node.id : nil
      }.reject {|_, v| v.nil?}

      new(hash).save
    end
  end
end
