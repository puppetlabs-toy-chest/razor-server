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
  end
end
