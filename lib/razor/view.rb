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
        :recipe => view_object_reference(policy.recipe),
        :broker => view_object_reference(policy.broker),
        :enabled => !!policy.enabled,
        :max_count => policy.max_count != 0 ? policy.max_count : nil,
        :configuration => {
          :hostname_pattern => policy.hostname_pattern,
          :root_password => policy.root_password,
        },
        :rule_number => policy.rule_number,
        :tags => policy.tags.map {|t| view_object_reference(t) }.compact,
        :nodes => { :id => view_object_url(policy) + "/nodes",
                    :count => policy.nodes.count,
                    :name => "nodes" }
      })
    end

    def tag_hash(tag)
      return nil unless tag

      view_object_hash(tag).merge({
        :rule => tag.rule,
        :nodes => { :id => view_object_url(tag) + "/nodes",
                    :count => tag.nodes.count,
                    :name => "nodes" },
        :policies => { :id => view_object_url(tag) + "/policies",
                       :count => tag.policies.count,
                       :name => "policies" }
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

    def recipe_hash(recipe)
      return nil unless recipe

      if recipe.base
        base = { :base => view_object_reference(recipe.base) }
      else
        base = {}
      end

      # FIXME: also return templates, requires some work for file-based
      # recipes
      view_object_hash(recipe).merge(base).merge({
        :os => {
          :name => recipe.os,
          :version => recipe.os_version }.delete_if {|k,v| v.nil? },
        :description => recipe.description,
        :boot_seq => recipe.boot_seq
      }).delete_if {|k,v| v.nil? }
    end

    def ts(date)
      date ? date.xmlschema : nil
    end

    def node_hash(node)
      return nil unless node

      boot_stage = node.policy ? node.recipe.boot_template(node) : nil
      if node.last_known_power_state.nil?
        power_state = nil
      elsif node.last_known_power_state
        power_state = 'on'
      else
        power_state = 'off'
      end

      view_object_hash(node).merge(
        :hw_info       => node.hw_hash,
        :dhcp_mac      => node.dhcp_mac,
        :policy        => view_object_reference(node.policy),
        :log           => { :id => view_object_url(node) + "/log",
                            :name => "log" },
        :tags          => node.tags.map { |t| view_object_reference(t) },
        :facts         => node.facts,
        :metadata      => node.metadata,
        :state         => {
          :installed    => node.installed,
          :installed_at => ts(node.installed_at),
          :stage        => boot_stage,
          :power        => power_state
        }.delete_if { |k,v| v.nil? },
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :last_checkin  => ts(node.last_checkin)
      ).delete_if {|k,v| v.nil? or ( v.is_a? Hash and v.empty? ) }
    end

    def collection_view(cursor, name)
      perm = "query:#{name}"
      cursor = cursor.all if cursor.respond_to?(:all)
      items = cursor.
        map {|t| view_object_reference(t)}.
        select {|o| check_permissions!("#{perm}:#{o[:name]}") rescue nil }
      {
        "spec" => spec_url("collections", name),
        "items" => items
      }.to_json
    end
  end
end
