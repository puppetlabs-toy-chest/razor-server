require_relative './util'

Sequel.migration do
  up do
    alter_table :policies do
      add_column :match_tags, :varchar, :size => 10, :default => 'AllOf', :null => false
    end

    #For this migration, all existing policies should be set to AllOf as this is
    #will preserve the original behaviour
    from(:policies).update(:match_tags => 'AllOf')

    alter_table :policies do
      #Policy match can be one of 'AllOf', 'AnyOf' or 'NoneOf'
      add_constraint :valid_policy_tags_match_values,
        "(match_tags = 'AllOf' OR match_tags = 'AnyOf' OR match_tags = 'NoneOf')"
    end
  end

  down do
    alter_table :policies do
      drop_constraint :valid_policy_tags_match_values
      drop_column :match_tags
    end
  end

end
