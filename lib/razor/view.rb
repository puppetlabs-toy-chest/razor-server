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
        :repo => view_object_reference(policy.repo),
        :installer => view_object_reference(policy.installer),
        :broker => view_object_reference(policy.broker),
        :enabled => !!policy.enabled,
        :max_count => policy.max_count != 0 ? policy.max_count : nil,
        :configuration => {
          :hostname_pattern => policy.hostname_pattern,
          :root_password => policy.root_password,
        },
        :rule_number => policy.rule_number,
        :tags => policy.tags.map {|t| view_object_reference(t) }.compact,
      })
    end

    def tag_hash(tag)
      return nil unless tag

      view_object_hash(tag).merge({
        :rule => tag.rule
      })
    end

    def repo_hash(repo)
      return nil unless repo

      view_object_hash(repo).merge({
        :iso_url => repo.iso_url
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

      if installer.base
        base = { :base => view_object_reference(installer.base) }
      else
        base = {}
      end

      # FIXME: also return templates, requires some work for file-based
      # installers
      view_object_hash(installer).merge(base).merge({
        :os => {
          :name => installer.os,
          :version => installer.os_version }.delete_if {|k,v| v.nil? },
        :description => installer.description,
        :boot_seq => installer.boot_seq
      }).delete_if {|k,v| v.nil? }
    end

    def node_hash(node)
      return nil unless node
      # @todo lutter 2013-09-09: if there is a policy, use boot_count to
      # provide a useful status about progress
      last_checkin_s = node.last_checkin.xmlschema if node.last_checkin
      view_object_hash(node).merge(
        :hw_info       => node.hw_hash,
        :dhcp_mac      => node.dhcp_mac,
        :policy        => view_object_reference(node.policy),
        :log           => { :id => view_object_url(node) + "/log",
                            :name => "log" },
        :tags          => node.tags.map { |t| view_object_reference(t) },
        :facts         => node.facts,
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :ip_address    => node.ip_address,
        :last_checkin  => last_checkin_s
      ).delete_if {|k,v| v.nil? }
    end
  end
end
