module Razor::View
  module Siren

    def siren_entity(klass, properties = nil, subentities=nil, actions=nil, links = nil)
      Razor::View::Siren.entity(klass, properties, subentities, actions, links)
    end

    def self.entity(klass, properties = nil, subentities=nil, actions=nil, links = nil)
      {
        :class => [klass].flatten,
        :properties => properties,
        :entities => (subentities and subentities.compact),
        :actions => (actions and actions.compact),
        :links => (links and links.compact),
      }.delete_if {|k, v| v.nil? }
    end

    def siren_action(name, title, url, klass, fields = nil, method="GET", encoding_type = nil)
      Razor::View::Siren.action(name, title, url, klass, fields, method, encoding_type)
    end

    def self.action(name, title, url, klass, fields = nil, method="GET", encoding_type = nil)
      {
        :name => name,
        :class => [klass].flatten,
        :title => title,
        :method => method,
        :href => url,
        :type => encoding_type,
        :fields => (fields and fields.compact),
      }.delete_if {|k, v| v.nil? }
    end

    def siren_action_field(name, type = 'text', value = nil)
      Razor::View::Siren::action_field(name, type, value)
    end

    def self.action_field(name, type = 'text', value = nil)
      {
        :name => name,
        :type => type,
        :value => value,
      }.delete_if {|k, v| v.nil? }
    end

    def siren_link(relation, url)
      Razor::View::Siren.link(relation, url)
    end

    def self.link(relation, url)
      {
        :rel => [relation].flatten,
        :href => url
      }
    end

    def siren_object_ref(klass, relation, url, name = nil)
      Razor::View::Siren.object_ref(klass, relation, url, name)
    end

    def self.object_ref(klass, relation, url, name=nil)
      properties = { :name => name } if name

      entity(klass, properties).merge({
        :rel => [relation].flatten.compact,
        :href => url,
      })
    end


    def siren_collection_entity(klass, entities, rel = nil, actions = [])
      siren_entity([Razor::View::class_url("collection"), klass],
        {}, entities, actions).merge(rel ? {:rel => [rel]} : {})
    end
  end
end
