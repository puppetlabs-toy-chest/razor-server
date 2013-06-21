Sequel.migration do
  up do
    extension(:constraint_validations)

    create_table :nodes do
      primary_key :id
      String      :hw_id, :null => false, :unique => true
      String      :facts
    end

    create_table :images do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :type, :null => false
      String      :path, :null => false
      String      :status
      String      :os_name
      String      :os_version

      validate do
        includes %w[mk os esxi], :type, :name => 'valid_image_types'
      end
    end

    create_table :policies do
      primary_key :id
      String      :name, :null => false, :unique => true
      TrueClass   :enabled
      Integer     :max_count
    end

    create_table :tags do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :rule
    end

    create_join_table( :tag_id => :tags, :policy_id => :policies)
  end

  down do
    extension(:constraint_validations)

    drop_table :policies_tags
    drop_table :tags
    drop_table :policies

    drop_table :models

    drop_constraint_validations_for :table => :images
    drop_table :images

    drop_table :nodes
  end
end
