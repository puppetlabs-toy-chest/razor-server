module Razor::API
  # The API transform for policy objects
  # 
  # An API-converted policy follows the following format:
  #
  #     {
  #       "id": __integer__,
  #       "name": __string__,
  #       "image_id": __integer__,
  #       "enabled": __boolean__,
  #       "max_count": __integer_or_null__,
  #       "configuration": {
  #         "hostname_pattern": __string__,
  #         "domain_name": __string__,
  #         "root_password": __string__
  #       },
  #       "tags": [ __string__, ]
  #     }
  #
  # where
  # -  `"id"` is the ID of the policy
  # -  `"name"` is the human-readable name of the policy
  # -  `"image_id"` is the ID of the image that the policy deploys
  # -  `"enabled"` denotes whether the policy is enabled or not
  # -  `"max_count" is the maximum number of nodes, or null if no maximum is
  #    specified
  # -  `"configuration"` is for values used to configure the node further after
  #    image installation, where
  #    -  `"hostname_pattern"` is the hostname for the node, after substituting
  #       all occurences of `%n` with the node ID
  #    -  `"domain_name"` is the domain name for the node
  #    -  `"root_password"` is the password for the root user account
  # -  `"tags"` is an array of tag names
  #
  # Here is an example of the tag format:
  #
  #     {
  #         "id": 45,
  #         "name": "ESXi_Basic_Small",
  #         "image_id": 27,
  #         "enabled": true,
  #         "max_count": 5,
  #         "configuration": {
  #             "hostname_pattern": "host-%n",
  #             "domain_name": "example.com",
  #             "root_password": "P@ssword"
  #         },
  #         "tags": [
  #             "vmware",
  #             "small_vm"
  #         ]
  #     }
  #
  class Policy < Transform

    def initialize(policy)
      @policy=policy
    end

    def to_hash
      return nil unless @policy

      {
        :id => @policy.id,
        :name => @policy.name,
        :image_id => @policy.image_id,
        :enabled => !!@policy.enabled,
        :max_count => @policy.max_count != 0 ? @policy.max_count : nil,
        :configuration => {
          :hostname_pattern => @policy.hostname_pattern,
          :domain_name => @policy.domainname,
          :root_password => @policy.root_password,
        },
        :tags => tags_array
      }
    end

    def attributes_hash
      @policy.attributes
    end

    def tags_array
      @policy.tags.map {|tag| tag.name}
    end
  end
end