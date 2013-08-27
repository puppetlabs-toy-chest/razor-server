require 'optparse'

module Razor::CLI
  module Siren

    class Field
      attr_reader :name, :type, :value
      attr_writer :value

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
      attr_accessor :path
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

      def optparse
        OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} #{path.join ' '}#{' FLAGS' if fields.any?}"
          opts.separator "\nFlags" if fields.any?
          self.fields.each do |field|
            opts.on "--#{field.name} #{field.name.upcase.tr '-','_'}" do |value|
              field.value = value
            end
          end
        end
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
      attr_accessor :path
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

      def optparse
        OptionParser.new do |opts|
          p_or_a= [@entities.any? ? "PATH" : nil, @actions.any? ? "ACTION" : nil]
          p_or_a = p_or_a.any? ? "[#{p_or_a.join ' OR '}]" : nil
          opts.banner = "Usage: #{$0} #{@path.join ' '} #{p_or_a}"
          opts.separator "Show details for '#{properties["name"] || 'object'}'"

          unless entities.empty?
            opts.separator "\nPaths:"
            entities.each do |entity|
              name = entity.properties["name"]
              opts.separator "  #{name}#{" - #{entity.title}" if entity.title}"
            end
          end

          unless actions.empty?
            opts.separator "\nActions:"
            actions.each do |action|
              opts.separator "  #{action.name}#{" - #{action.title}" if action.title}"
            end
          end
        end
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

        case type.first
        when  /collection\Z/
          CollectionEntity.new(type, properties, entities, actions, links, title, relation, href)
        when /api\Z/
          RootEntity.new(type, properties, entities, actions, links, title, relation, href)
        else
          self.new(type, properties, entities, actions, links, title, relation, href)
        end
      end
    end

    class RootEntity < Entity
      def optparse(parse)
        additional_opts = parse.optparse.dup
        additional_opts.banner = "Options:"
        OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} [options] [PATH OR ACTION]"

          opts.separator "\nPaths: #{'(none)' if entities.empty?}"
          entities.each do |entity|
            name = entity.properties["name"]
            opts.separator "  #{name}#{" - #{entity.title}" if entity.title}"
          end

          opts.separator "\nActions: #{'(none)' if actions.empty?}"
          actions.each do |action|
            opts.separator "  #{action.name}#{" - #{action.title}" if action.title}"
          end

          opts.separator "\n#{additional_opts}"
        end
      end
    end

    class CollectionEntity < Entity
      def optparse
        OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} #{path.join ' '} [PATH OR ACTION]"
          opts.separator title if title

          opts.separator "\nActions: #{'(none)' if actions.empty?}"
          actions.each do |action|
            opts.separator "  #{action.name}#{" - #{action.title}" if action.title}"
          end
        end
      end
    end
  end
end
