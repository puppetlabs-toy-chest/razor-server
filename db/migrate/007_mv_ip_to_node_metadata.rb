# -*- encoding: utf-8 -*-
require_relative './util'

Sequel.migration do
  up do
    extension(:constraint_validations)

    self[:nodes].all.each do |n|
      metadata = JSON::parse(n[:metadata])
      metadata[:ip] = n[:ip_address] if n[:ip_address]
      self[:nodes].where(:id => n[:id]).update(:metadata => metadata.to_json)
    end
    drop_column :nodes, :ip_address
  end

  # No down migration as it's a bit of work, and we can probably do without
  # one
end
