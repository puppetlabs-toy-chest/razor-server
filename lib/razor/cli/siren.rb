require 'optparse'

module Razor::CLI
  module Siren

    class Field
      attr_reader :name, :type, :value

      def initialize(name, type, value)
        @name = name
        @type = type
        @value = value
      end

      def self.parse(field_obj)
        self.new(*field_obj.values_at("name", "type", "value"))
      end
    end

    class Properties < Hash
      def self.parse(properties_obj)
        self.new.merge!(properties_obj)
      end
    end

    class Action
      attr_reader :name, :title, :url, :method, :fields

      def initialize(name, title, url, method, fields)
        @path = []
        @name = name
        @title = title
        @url = url
        @method = method
        @fields = fields
      end

      def self.parse(action_obj)
        properties = action_obj.values_at("name", "title", "href", "method")
        fields = (action_obj["fields"] || []).map {|x| Field.parse(x)}
        self.new(*properties, fields)
      end
    end

    class Link
      attr_reader :relation, :href

      def initialize(rel, href)
        @relation = rel
        @href = href
      end

      def self.parse(link_obj)
        self.new(*link_obj.values_at("rel","href"))
      end
    end

    class Entity
      attr_reader :type, :properties, :entities, :actions, :links, :title, :relation, :href

      def initialize(type, properties, entities, actions, links, title, rel=nil, href=nil)
        @path = []
        @type = type
        @properties = properties
        @entities = entities
        @actions = actions
        @links = links
        @title = title
        @relation = rel
        @href = href
      end

      def self.parse(entity_obj)
        type = entity_obj["class"] || []
        properties = Properties.parse(entity_obj["properties"] || {})
        entities = (entity_obj["entities"] || []).map {|x| self.parse(x)}
        actions = (entity_obj["actions"] || []).map {|x| Action.parse(x)}
        links = (entity_obj["links"] || []).map {|x| Link.parse(x)}
        title = entity_obj["title"]
        relation =  entity_obj["rel"] || []
        href = entity_obj["href"]

        self.new(type, properties, entities, actions, links, title, relation, href)
      end
    end
  end
end
