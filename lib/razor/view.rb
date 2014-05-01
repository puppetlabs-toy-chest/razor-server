# -*- encoding: utf-8 -*-
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
        :task => view_object_reference(policy.task),
        :broker => view_object_reference(policy.broker),
        :enabled => !!policy.enabled,
        :max_count => policy.max_count != 0 ? policy.max_count : nil,
        :configuration => {
          :hostname_pattern => policy.hostname_pattern,
          :root_password => policy.root_password,
        },
        :tags => policy.tags.map {|t| view_object_reference(t) }.compact,
        :node_metadata => policy.node_metadata || {},
        :nodes => { :id => view_object_url(policy) + "/nodes",
                    :count => policy.nodes.count,
                    :name => "nodes" }
      }).delete_if {|k,v| v.nil? or ( v.is_a? Hash and v.empty? ) }
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

      task = Razor::Task.find(repo.task_name) rescue nil
      view_object_hash(repo).merge({
        :iso_url => repo.iso_url,
        :url => repo.url,
        :task => view_object_hash(task)
      })
    end

    def broker_hash(broker)
      return nil unless broker

      view_object_hash(broker).merge(
        :configuration   => broker.configuration,
        :"broker-type"   => broker.broker_type,
        :policies        => { :id => view_object_url(broker) + "/policies",
                              :count => broker.policies.count,
                              :name => "policies" })
    end

    def task_hash(task)
      return nil unless task

      if task.base
        base = { :base => view_object_reference(task.base) }
      else
        base = {}
      end

      # FIXME: also return templates, requires some work for file-based
      # tasks
      view_object_hash(task).merge(base).merge({
        :os => {
          :name => task.os,
          :version => task.os_version }.delete_if {|k,v| v.nil? },
        :description => task.description,
        :boot_seq => task.boot_seq
      }).delete_if {|k,v| v.nil? }
    end

    def ts(date)
      date ? date.xmlschema : nil
    end

    def node_hash(node)
      return nil unless node

      boot_stage = node.policy ? node.task.boot_template(node) : nil

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
          :installed    => node.installed || false,
          :installed_at => ts(node.installed_at),
          :stage        => boot_stage,
        }.delete_if { |k,v| v.nil? },
        :power => {
          :desired_power_state        => node.desired_power_state,
          :last_known_power_state     => node.last_known_power_state,
          :last_power_state_update_at => node.last_power_state_update_at
        }.delete_if { |k,v| v.nil? },
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :last_checkin  => ts(node.last_checkin)
      ).delete_if {|k,v| v.nil? or ( v.is_a? Hash and v.empty? ) }
    end

    def command_hash(cmd)
      # @todo lutter 2014-03-27: we strip the backtrace because it tells
      # normal users nothing. For debugging, it would be nice to make that
      # available through the API at some point
      errors = (cmd.error || []).reject { |e| e.nil? }.map do |e|
        h = e.dup
        h.delete('backtrace')
        h
      end
      view_object_hash(cmd).merge(
        :command  => cmd.command,
        :params   => cmd.params,
        :errors   => errors,
        :status   => cmd.status,
        :submitted_at => ts(cmd.submitted_at),
        :submitted_by => cmd.submitted_by,
        :finished_at  => ts(cmd.finished_at)
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
