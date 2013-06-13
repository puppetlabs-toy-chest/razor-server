Sequel.migration do
  change do
    create_table :nodes do
      primary_key :id
      String      :hw_id, :null => false, :unique => true
      column      :facts, 'json'
    end

    create_table :images do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :type, :null => false
      String      :path, :null => false
      String      :status
      String      :os_name
      String      :os_version
      constraint(:images_type_ck, :type => %w[mk os esxi])
    end

    create_table :models do
      primary_key :id
      String      :name, :null => false, :unique => true
      foreign_key :image_id, :null => false
      String      :hostname_pattern
    end

    create_table :policies do
      primary_key :id
      String      :name, :null => false, :unique => true
      foreign_key :model_id, :models, :null => false
      TrueClass   :enabled
      Integer     :max_count
    end

    create_table :tags do
      primary_key :id
      String      :name, :null => false, :unique => true
      column      :rule, 'json'
    end

    create_join_table( :tag_id => :tags, :policy_id => :policies)
  end
end
