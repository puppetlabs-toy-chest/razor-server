Sequel.migration do
  change do
    create_table :nodes do
      primary_key :id
      String      :hw_id, :null => false, :unique => true
    end
  end
end
