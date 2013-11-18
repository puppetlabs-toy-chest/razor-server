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
    end
  end
end
