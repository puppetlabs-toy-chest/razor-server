# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :repos do
      add_column            :url, :varchar, :size => 1000

      set_column_allow_null :iso_url
      add_constraint        :repos_url_xor_iso_url_not_null,
          "(iso_url is null and url is not null)
        or (iso_url is not null and url is null)"

      validate do
        format URL_RX, :url, :name => 'url_is_simple',
                             :allow_nil => true

        # Because of a limitation in Sequel, we drop iso_url_is_simple here
        # and add it in the next alter_table block
        drop   'iso_url_is_simple'
      end
    end

    alter_table :repos do
      validate do
        format URL_RX, :iso_url, :name => 'iso_url_is_simple',
                                 :allow_nil => true
      end
    end
  end

  down do
    alter_table :repos do
      drop_column         :url
      set_column_not_null :iso_url
    end
  end
end
