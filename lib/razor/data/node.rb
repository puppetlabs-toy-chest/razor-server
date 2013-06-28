module Razor::Data
  class NodeNotBoundError < RuntimeError; end

  class Node < Sequel::Model
    plugin :serialization, :json, :facts
    plugin :serialization, :json, :log

    many_to_one :policy

    def installer
      policy ? policy.installer : Razor::Installer.mk_installer
    end

    def tags
      Tag.match(self)
    end

    def hostname
      raise NodeNotBoundError, "hostname" unless policy
      policy.hostname_pattern.gsub(/%n/, id.to_s)
    end

    def root_password
      raise NodeNotBoundError, "root_password" unless policy
      policy.root_password
    end

    def domainname
      raise NodeNotBoundError, "root_password" unless policy
      policy.domainname
    end

    def fqdn
      "#{hostname}.#{domainname}"
    end

    def log_append(hash)
      self.log ||= []
      hash[:timestamp] ||= Time.now.to_i
      hash[:severity] ||= 'info'
      self.log << hash
    end

    def bind(policy)
      self.policy = policy
      self.boot_count = 0
      # FIXME: Populate hostname, domainname etc.
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

    def self.checkin(hw_id, body)
      if node = lookup(hw_id)
        if body['facts'] != node.facts
          node.facts = body['facts']
          node.save
        end
      else
        node = create(:hw_id => hw_id, :facts => body['facts'])
      end
      Policy.bind(node) unless node.policy
      if node.policy
        # FIXME: Bound to a policy, what do we do next ?
      end
      { :action => :none }
    end

    def self.lookup(hw_id)
      self[:hw_id => hw_id]
    end

    def self.boot(hw_id, dhcp_mac = nil)
      unless node = lookup(hw_id)
        node = Node.create(:hw_id => hw_id)
      end
      node.dhcp_mac = dhcp_mac if dhcp_mac && dhcp_mac != ""
      node.boot_count += 1
      node.save
    end
  end
end
