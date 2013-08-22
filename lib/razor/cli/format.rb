require 'terminal-table'
require 'pp'

# This is supposed to be just enough for our purposes, and no more
class String
  def pluralize
    case self
    when /cy\Z/ then self[0..-2] + "ies"
    else self + "s"
    end
  end
end

module Razor::CLI
  module Format
    PriorityKeys = %w[ name ]
    KeyAliases = { "_href" => "Path"}

    def class_name(url)
      [url].flatten.first.split('/').last.capitalize
    end

    def format_entity(entity)
      if entity.type.first.end_with? "collection"
        format_entity_list(entity.entities)
      else
        format_single_entity(entity)
      end
    end

    def format_entity_list(entities)
      types = entities.map {|ent| ent.type}.uniq
      types.map do |type|
        format_homogenous_list(entities.select {|ent| ent.type==type})
      end.join "\n\n"
    end

    def format_homogenous_list(entities)
      table = Terminal::Table.new do |t|

        allKeys = entities.map {|ent| ent.properties}.map(&:keys).flatten.uniq
        orderedKeys = order_keys(allKeys)

        # If this is a list of references
        if entities.all? {|ent| ent.href }
          orderedKeys << "_href"
          entities.each {|ent| ent.properties["_href"] = URI.parse(ent.href).path }
        end

        t.headings = orderedKeys.map { |key| KeyAliases[key] || key.capitalize }

        t.rows = entities.map { |ent| ent.properties.values_at(*orderedKeys) }
      end

      "#{class_name(entities.first.type).pluralize}\n#{table.to_s}"
    end

    def format_single_entity(entity)
      properties_table = Terminal::Table.new do |table|
        keys = order_keys (entity.properties ||= {}).keys
        table.headings = ["Property", "Value"]
        table.rows = keys.map do |key|
          [ (KeyAliases[key]||key.capitalize), PP.pp((entity.properties[key]),"")]
        end
      end

      entities = entity.entities.map do |ent|
        "  - #{format_entity(ent).to_s.gsub("\n","\n    ")}"
      end.join("\n\n")

      "#{class_name(entity.type)}\n#{properties_table}#{entities}"
    end

    def order_keys(keys)
      (PriorityKeys & keys) + (keys - PriorityKeys)
    end
  end
end
