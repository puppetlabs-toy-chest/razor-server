require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :nodes do
      add_column :ipmi_hostname, :varchar, :size => 255, :null => true
      # these size limitations are based on the IPMI v2 spec.
      add_column :ipmi_username, :varchar, :size => 32,  :null => true
      add_column :ipmi_password, :varchar, :size => 20,  :null => true

      # you can only have a null IPMI hostname if you also have the other
      # fields empty; setting anything else requires a not-null hostname.
      add_constraint  :ipmi_require_hostname_if_user_or_pass, <<SQL
(ipmi_hostname IS NULL AND ipmi_username IS NULL AND ipmi_password IS NULL) OR
(ipmi_hostname IS NOT NULL)
SQL

      # This is the classic tri-state field: true, false, unknown
      # We maintain the timestamp from the application, because that is where
      # we draw the information from; this is just a cache reflecting history.
      add_column :last_known_power_state, :boolean, :null => true
      add_column :last_power_state_update_at, 'timestamp with time zone', :null => true

      validate do
        # these all validate the same way.
        [:ipmi_hostname, :ipmi_username, :ipmi_password].each do |column|
          format NAME_RX, column, :name => "#{column}_is_simple", :allow_nil => true
        end
      end
    end
  end

  down do
    alter_table :nodes do
      drop_constraint :ipmi_require_hostname_if_user_or_pass

      drop_column :ipmi_hostname
      drop_column :ipmi_username
      drop_column :ipmi_password

      drop_column :last_known_power_state
      drop_column :last_power_state_update_at
    end
  end
end
