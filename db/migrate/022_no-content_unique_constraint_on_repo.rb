# -*- encoding: utf-8 -*-
require_relative './util'

# Now that the no-content option is in place, we need a way to
# create repos without requiring `url` or `iso-url`, since
# nothing needs to be downloaded and/or extracted. This migration
# changes the constraint on the `repos` relation to allow both to
# be null.
Sequel.migration do
  up do
    extension(:constraint_validations)

    alter_table :repos do
      drop_constraint        :repos_url_xor_iso_url_not_null

      add_constraint        :repos_url_is_null_or_iso_url_is_null,
                            "(iso_url is null or url is null)"
    end
  end

  down do
    extension(:constraint_validations)

    alter_table :repos do
      drop_constraint        :repos_url_is_null_or_iso_url_is_null

      add_constraint        :repos_url_xor_iso_url_not_null,
                            "(iso_url is null and url is not null)
        or (iso_url is not null and url is null)"
    end
  end
end
