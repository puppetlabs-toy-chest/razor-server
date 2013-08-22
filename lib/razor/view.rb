module Razor
  module View

    # We use this URL to generate unique names for relations in links
    # etc. There is no guarantee that there is any contant at these URL's.
    SPEC_URL = "http://api.puppetlabs.com/razor/v1"

    def self.spec_url(*path)
      SPEC_URL + ('/spec/' + path.join("/")).gsub(%r'//+', '/')
    end

    def self.class_url(klass)
      # Drop the 'Razor:: (and Data::)' part since it's redundant
      path = klass.to_s.gsub(/Razor::(Data::)?/,'').tr(':','/').downcase

      SPEC_URL + "/class/#{path}".gsub(%r'//+', '/')
    end

    def spec_url(*paths)
      Razor::View::spec_url(*paths)
    end

    def class_url(klass)
      Razor::View::class_url(klass)
    end

    def object_name(obj)
      # e.g., Razor::Data::Tag -> "tag"
      case obj
      when Class then obj
      else obj.class
      end.name.split("::").last.downcase.underscore
    end

    def collection_name(obj)
      # e.g., Razor::Data::Tag -> "tags"
      object_name(obj).pluralize
    end

    def view_object_url(obj)
      compose_url "api", "collections", collection_name(obj), obj.name
    end

    def view_reference_object(obj, relation)
      return nil unless obj

      siren_object_ref(class_url(obj.class), relation, view_object_url(obj),
        obj.respond_to?(:name) ? obj.name : nil)
    end

    def view_reference_collection(type, objects, parent = nil, actions = [])
      if parent.nil?
        collection_rel = nil
        object_rel = spec_url("collection", "member")
      else
        collection_rel = spec_url(collection_name(parent), "member", collection_name(type))
        object_rel = spec_url("collection", "member")
      end
      entities = objects.map {|obj| view_reference_object(obj, object_rel) }

      siren_collection_entity(class_url(type), entities, collection_rel, actions)
    end

    def view_object_hash(object, actions)
      helper = object.class.to_s.demodulize.singularize.underscore + "_hash"
      if respond_to? helper.to_sym
        send helper.to_sym, object, actions
      else
        raise "No helper exists for #{object}"
      end
    end

    def policy_hash(policy, actions = nil)
      return nil unless policy

      properties = {
        :name => policy.name,
        :enabled => !!policy.enabled,
        :max_count => policy.max_count != 0 ? policy.max_count : nil,
        :configuration => {
          :hostname_pattern => policy.hostname_pattern,
          :root_password => policy.root_password,
        },
        :line_number => policy.line_number,
      }

      tags_entity = view_reference_collection(Razor::Data::Tag, policy.tags, policy)

      image_relation = spec_url("collections", collection_name(policy), "member", object_name(policy.image))
      image_entity = view_reference_object policy.image, image_relation

      siren_entity(class_url(policy.class), properties, [tags_entity, image_entity], actions)
    end

    def tag_hash(tag, actions = nil)
      return nil unless tag
      properties = {
        :name => tag.name,
        :rule => tag.matcher.rule,
      }

      siren_entity(class_url(tag.class), properties, nil, actions)
    end

    def image_hash(image, actions = nil)
      return nil unless image

      properties = {
        :name => image.name,
        :image_url => image.image_url
      }

      siren_entity(class_url(image.class), properties, nil, actions)
    end

    def broker_hash(broker, actions = nil)
      return nil unless broker

      properties = {
        :name            => broker.name,
        :configuration   => broker.configuration,
        :"broker-type"   => broker.broker_type,
      }

      siren_entity(class_url(broker.class), properties, nil, actions)
    end

    def installer_hash(installer, actions = nil)
      return nil unless installer

      # FIXME: also return templates, requires some work for file-based
      # installers
      properties = {
        :name => installer.name,
        :os => {
          :name => installer.os,
          :version => installer.os_version },
        :description => installer.description,
        :boot_seq => installer.boot_seq
      }

      siren_entity(class_url(installer.class), properties, nil, actions)
    end

    def node_hash(node, actions = nil)
      return nil unless node
      properties = {
        :hw_id         => node.hw_id,
        :dhcp_mac      => node.dhcp_mac,
        :facts         => node.facts,
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :ip_address    => node.ip_address,
        :boot_count    => node.boot_count
      }.delete_if {|k,v| v.nil? }

      policy_relation = spec_url("collections", collection_name(node), "member", object_name(node.policy))
      policy_entity = view_reference_object node.policy, policy_relation

      log_relation = spec_url("collections", collection_name(node), "member", "log")
      log_entity = siren_object_ref(class_url(node.class.to_s+"/log"),
        log_relation, view_object_url(node) + "/log", "log")

      siren_entity(class_url(node.class), properties,
        [policy_entity, log_entity].compact, actions)
    end
  end
end

# This is only moderately view-related, but it does have to do with formatting
# output, so here it is.
class String
  def indefinite_article
    "aeiou".include?(self[0].downcase) ? "an" : "a"
  end
end

require_relative 'view/siren'
