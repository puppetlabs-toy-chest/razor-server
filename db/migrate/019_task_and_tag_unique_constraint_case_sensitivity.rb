# -*- encoding: utf-8 -*-
require_relative './util'

def get_new_name(table, column, current_name, differentiator = 1)
  to_test = current_name + differentiator.to_s
  entity = self[table].where{|o| {o.lower(column)=>(o.lower(to_test))}}.all
  if entity.empty?
    # Not there, ship it
    to_test
  else
    # This is not the name you're looking for
    get_new_name(table, column, current_name, differentiator + 1)
  end
end

def resolve_duplicates(table, column)
  group_by_unique = Hash.new { Array.new }
  self[table].all.each do |item|
    key = item[column].downcase
    group_by_unique.store(key, group_by_unique[key] << item[column])
    # Sorting and reversing so "abc" will be before "Abc".
    # Kind of arbitrary, but it's more deterministic this way.
    group_by_unique[key] = group_by_unique[key].sort.reverse
  end
  duplicates = group_by_unique.select { |_, values| values.size > 1 }
  duplicates.each do |_, items|
    _, *rest = *items
    # The first can remain the same, but the rest need to change.
    rest.each do |item|
      new_name = get_new_name(table, column, item)
      puts "#{table}: Changing #{item} to #{new_name} to resolve duplicate issue"
      self[table].where(column => item).update(column => new_name)
    end
  end
end

# Create a case-insensitive uniqueness constraint on the `tags` table's `name` field.
# This requires a resolution for renaming existing tags. If 'mytag' and 'MyTag' both
# exist in the database, this will rename 'MyTag' to 'MyTag1'.
Sequel.migration do
  up do
    extension(:constraint_validations)

    resolve_duplicates(:tags, :name)

    alter_table :tags do
      drop_constraint :tags_name_key
      add_index  Sequel.function(:lower, :name), :unique => true, :name => 'tags_name_index'
      validate do
        format NAME_RX, :name,        :name => 'tag_name_is_simple'
      end
    end

    # This does not need to modify the :tasks table because the 'tasks_name_index'
    # in place already performs the case-insensitive uniqueness comparison.
  end

  down do
    # Cannot be reversed since the original names of the duplicates are gone.
  end
end
