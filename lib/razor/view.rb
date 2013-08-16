module Razor
  module View

    def view_object_url(obj)
      # e.g., Razor::Data::Tag -> "tags"
      type = obj.class.name.split("::").last.downcase.underscore.pluralize
      compose_url "api", "collections", type, obj.name
    end

    # The definition of an object reference: it has a `url` field which is
    # unique across all objects, an `obj_id` field that is unique among objects
    # of the same type, and a human-readable `name` field, which can be nil.
    def view_object_reference(obj)
      return nil unless obj

      {
        :spec => compose_url("spec","object","reference"),
        :url => view_object_url(obj),
        :obj_id => obj.id,
        :name => obj.respond_to?(:name) ? obj.name : nil,
      }
    end

    # The definition of a basic object type: it has a `spec` field, which
    # identifies the type of the object, an `id` field, which uniquely
    # identifies the object on the server, and a `name` field, which provides
    # a human-readable name for the object. This is the *baseline* definition
    # of an object; it is expected to be `#merge`d with a hash that overrides
    # :spec, and that contains type-specific fields.
    def view_object_hash(obj)
      return nil unless obj

      {
        :spec => compose_url("spec","object"),
        :id => view_object_url(obj),
        :name => obj.name
      }
    end

    def policy_hash(policy)
      return nil unless policy

      view_object_hash(policy).merge({
        :spec => compose_url("spec", "object", "policy"),

        :image => view_object_reference(policy.image),
        :enabled => !!policy.enabled,
        :max_count => policy.max_count != 0 ? policy.max_count : nil,
        :configuration => {
          :hostname_pattern => policy.hostname_pattern,
          :root_password => policy.root_password,
        },
        :line_number => policy.line_number,
        :tags => policy.tags.map {|t| view_object_reference(t) }.compact,
      })
    end

    def tag_hash(tag)
      return nil unless tag

      view_object_hash(tag).merge({
        :spec => compose_url("spec", "object", "tag"),

        :matcher => {
          :rule => tag.matcher.rule
        }
      })
    end

    def image_hash(image)
      return nil unless image

      view_object_hash(image).merge({
        :spec => compose_url("spec", "object", "image"),
        :image_url => image.image_url
      })
    end

    def broker_hash(broker)
      return nil unless broker

      view_object_hash(broker).merge(
        :spec          => compose_url('spec', 'object', 'broker'),
        :configuration => broker.configuration,
        :broker_type   => broker.broker_type)
    end

    def installer_hash(installer)
      return nil unless installer

      # FIXME: also return templates, requires some work for file-based
      # installers
      view_object_hash(installer).merge({
        :os => {
          :name => installer.os,
          :version => installer.os_version },
        :description => installer.description,
        :boot_seq => installer.boot_seq
      })
    end
  end
end
