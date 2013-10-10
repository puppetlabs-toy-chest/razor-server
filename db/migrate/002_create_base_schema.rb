require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    create_table :repos do
      primary_key :id

      # We want case-folded uniqueness for name, since that avoids challenges
      # that we might meet with, eg, case preserving but insensitive platforms
      # in the future.  Like, say, URL comparison in the mind of many people,
      # even if the standard claims otherwise.
      #
      # @todo danielp 2013-06-26: what is a reasonable limit here?  I feel
      # like it should be in the 40-60 character region at absolute most,
      # since this is a human label and, honestly, not a novella.
      column :name, :varchar, :size => 250, :null => false
      index  Sequel.function(:lower, :name), :unique => true, :name => 'repos_name_index'

      column :iso_url, :varchar, :size => 1000, :null => false

      # Our temporary working directory, used while actively downloading and
      # unpacking content.
      column :tmpdir, :varchar, :size => 4096, :null => true

      validate do
        format NAME_RX, :name, :name => 'repo_name_is_simple'

        format URL_RX, :iso_url, :name => 'iso_url_is_simple'
      end
    end

    create_table :installers do
      primary_key :id

      # The unique constraint here is redundant with the much stricter
      # index, but we need it for the FK from base
      column :name, :varchar, :size => 250, :null => false, :unique => true
      index  Sequel.function(:lower, :name), :unique => true, :name => 'installers_name_index'

      column :os, :varchar, :size => 1000, :null => false
      column :os_version, :varchar, :size => 1000

      column :description, :varchar, :size => 1000

      foreign_key :base, :installers, :type => :varchar, :key => :name

      # JSON hash of boot_count => template name
      String :boot_seq, :null => false, :default => '{}'
      # JSON hash of template name => template text
      String :templates, :default => '{}'

      validate do
        format NAME_RX, :name, :name => 'installer_name_is_simple'
      end
    end

    create_table :brokers do
      primary_key :id
      column      :name, :varchar, :size => 250, :null => false
      index  Sequel.function(:lower, :name), :unique => true, :name => 'brokers_name_index'
      # JSON hash of configuration key/value pairs supplied by the user.
      # We don't really need the full weight of JSON, but better compatible
      # with the rest of the system and less surprising than efficient.
      column :configuration, :text, :null => false, :default => '{}'

      # Tie our in-database version to the on-disk broker...
      column :broker_type, :varchar, :size => 250, :null => false

      validate do
        format NAME_RX, :name,        :name => 'broker_name_is_simple'
        format NAME_RX, :broker_type, :name => 'broker_type_is_simple'
      end
    end

    create_table :policies do
      primary_key :id
      String      :name, :null => false, :unique => true
      foreign_key :repo_id, :repos, :null => false
      # FIXME: this needs to become an FK as soon as we have an installers table
      String      :installer_name, :null => false
      String      :hostname_pattern, :null => false
      String      :root_password, :null => false

      TrueClass   :enabled
      Integer     :max_count
      Integer     :rule_number, :null => false, :unique => true

      foreign_key :broker_id, :brokers, :null => false
    end

    create_table :tags do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :matcher, :null => false
    end

    create_table :nodes do
      primary_key :id

      column :hw_info, 'Text[]', :null => false

      String      :dhcp_mac
      index  Sequel.function(:lower, :dhcp_mac), :unique => true,
                                                 :name => 'nodes_dhcp_mac_index'

      foreign_key :policy_id, :policies

      String      :facts

      # The fully qualified name of the host, set when we bind to a policy
      String      :hostname
      String      :root_password
      constraint  :nodes_policy_sets_hostname,
                  "policy_id is NULL or hostname is not NULL"
      constraint  :nodes_policy_sets_root_password,
                  "policy_id is NULL or root_password is not NULL"

      # FIXME: Determine if we even need to store this (it only seems to be
      # used to log into the node via ssh to setup the broker; and we
      # should do that by pulling a broker install script from the node)
      String      :ip_address
      Integer     :boot_count, :default => 0
      column      :last_checkin, 'timestamp with time zone'
    end

    create_table :node_log_entries do
      foreign_key :node_id, :nodes, :null => false, :on_delete => :cascade
      column      :timestamp, 'timestamp with time zone',
                  :default => :now.sql_function
      String      :entry, :null => false
    end

    # Join table for nodes/tags; we can't use create_join_table since we
    # want the association to disappear if either end disappears
    create_table :nodes_tags do
      foreign_key :node_id, :nodes, :null=>false, :on_delete => :cascade
      foreign_key :tag_id, :tags, :null=>false, :on_delete => :cascade
      primary_key [:node_id, :tag_id]
      index [:node_id, :tag_id]
    end

    create_join_table( :tag_id => :tags, :policy_id => :policies)
  end

  down do
    extension(:constraint_validations)

    drop_table :policies_tags
    drop_table :tags
    drop_table :policies

    drop_table :models

    drop_constraint_validations_for :table => :repos
    drop_table :repos

    drop_table :nodes
  end
end
