module Razor::Data
  class Node < Sequel::Model
    plugin :serialization, :json, :facts
    plugin :serialization, :json, :log

    many_to_one :policy

    # Return the `hw_id` field as `name` to the outside.
    #
    # @todo danielp 2013-08-19: this is kind of a hack to make the generic
    # view code work reasonably correctly in the face of this being the *one*
    # data object that differs from the others.  In the longer term we should
    # figure out what the right solution looks like, but this will get us
    # working for now.
    alias_method 'name', 'hw_id'

    def installer
      policy ? policy.installer : Razor::Installer.mk_installer
    end

    def tags
      Tag.match(self)
    rescue Razor::Matcher::RuleEvaluationError => e
      log_append :severity => "error", :msg => "RAZOR: Error while matching tags: #{e}"
      save
      raise e
    end

    def domainname
      return nil if hostname.nil?
      hostname.split(".").drop(1).join(".")
    end

    def shortname
      return nil if hostname.nil?
      hostname.split(".").first
    end

    def log_append(hash)
      self.log ||= []
      hash[:timestamp] ||= Time.now.to_i
      hash[:severity] ||= 'info'
      # Roundtrip the hash through JSON to make sure we always have the
      # same entries in the log that we would get from loading from DB
      # (otherwise we could have symbols, which will turn into strings on
      # reloading)
      self.log << JSON::parse(hash.to_json)
    end

    def bind(policy)
      self.policy = policy
      self.boot_count = 0
      self.root_password = policy.root_password
      self.hostname = policy.hostname_pattern.gsub(/\$\{\s*id\s*\}/, id.to_s)
    end

    # This is a hack around the fact that the auto_validates plugin does
    # not play nice with the JSON serialization plugin (the serializaton
    # happens in the before_save hook, which runs after validation)
    #
    # To avoid spurious error messages, we tell the validation machinery to
    # expect a Hash resp. an Array
    # FIXME: Figure out a way to address this issue upstream
    def schema_type_class(k)
      if k == :facts
        Hash
      elsif k == :log
        Array
      else
        super
      end
    end

    def self.checkin(body)
      hw_id = canonicalize_hw_id(body['hw_id'])
      if node = lookup(hw_id)
        if body['facts'] != node.facts
          node.facts = body['facts']
          node.save
        end
      else
        node = create(:hw_id => hw_id, :facts => body['facts'])
      end
      action = :none
      Policy.bind(node) unless node.policy
      if node.policy
        node.log_append(:action => :reboot, :policy => node.policy.name)
        node.save
        action = :reboot
      end
      { :action => action }
    end

    def self.canonicalize_hw_id(input)
      input.gsub(/[_:]/, '').downcase
    end

    def self.lookup(hw_id)
      self[:hw_id => canonicalize_hw_id(hw_id)]
    end

    def self.boot(hw_id, dhcp_mac = nil)
      node = lookup(hw_id) || Node.create(:hw_id => canonicalize_hw_id(hw_id))
      node.dhcp_mac = dhcp_mac if dhcp_mac && dhcp_mac != ""
      node.boot_count += 1
      node.save
    end
  end
end
