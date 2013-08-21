module Razor
  module View

    # We use this URL to generate unique names for relations in links
    # etc. There is no guarantee that there is any contant at these URL's.
    SPEC_URL = "http://api.puppetlabs.com/razor/v1"

    def self.spec_url(*path)
      SPEC_URL + ('/' + path.join("/")).gsub(%r'//+', '/')
    end

    def spec_url(*paths)
      Razor::View::spec_url(*paths)
    end

    def collection_name(obj)
      # e.g., Razor::Data::Tag -> "tags"
      obj.class.name.split("::").last.downcase.underscore.pluralize
    end

    def view_object_url(obj)
      compose_url "api", "collections", collection_name(obj), obj.name
    end

    # The definition of an object reference: it has a `id` field which is
    # a globally unique URL, and a `name` field that is unique among objects
    # of the same type
    def view_object_reference(obj)
      view_object_hash(obj)
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
        :spec => spec_url("collections", collection_name(obj), "member"),
        :id => view_object_url(obj),
        :name => obj.name
      }
    end

    def policy_hash(policy)
      return nil unless policy

      view_object_hash(policy).merge({
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
        :rule => tag.rule
      })
    end

    def image_hash(image)
      return nil unless image

      view_object_hash(image).merge({
        :image_url => image.image_url
      })
    end

    def broker_hash(broker)
      return nil unless broker

      view_object_hash(broker).merge(
        :spec            => compose_url('spec', 'object', 'broker'),
        :configuration   => broker.configuration,
        :"broker-type"   => broker.broker_type)
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

    def node_hash(node)
      return nil unless node
      view_object_hash(node).merge(
        :hw_id         => node.hw_id,
        :dhcp_mac      => node.dhcp_mac,
        :policy        => view_object_reference(node.policy),
        :log           => { :id => view_object_url(node) + "/log",
                            :name => "log" },
        :facts         => node.facts,
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :ip_address    => node.ip_address,
        :boot_count    => node.boot_count
      ).delete_if {|k,v| v.nil? }
    end
  end
end
