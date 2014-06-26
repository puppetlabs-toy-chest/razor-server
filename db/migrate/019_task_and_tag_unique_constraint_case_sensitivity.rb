# -*- encoding: utf-8 -*-
require_relative './util'

def get_new_name(clazz, current_name, differentiator = 1)
  to_test = current_name + differentiator.to_s
  if clazz.find(name: /^#{Regexp.escape(to_test)}$/i).nil?
    # Not there, ship it
    to_test
  else
    # This is not the name you're looking for
    get_new_name(clazz, current_name, differentiator + 1)
  end
end

def resolve_duplicates(clazz, attribute_name)
  # Get all tags, grouped by lowercase name
  all = clazz.all
  uniq = Hash.new { Array.new }
  all.each do |item|
    key = item.send(attribute_name).downcase
    uniq.store(key, uniq[key] << item)
    # Sorting and reversing so "abc" will be before "Abc".
    # Kind of arbitrary, but it's more deterministic this way.
    uniq[key] = uniq[key].sort_by(&attribute_name).reverse
  end
  uniq.each do |_, items|
    _, *rest = *items
    # The first can remain the same, but the rest need to change.
    rest.each do |item|
      old_name = item.send(attribute_name)
      item.send("#{attribute_name.to_s}=", get_new_name(clazz, item.send(attribute_name)))
      puts "#{clazz}: Changing #{old_name} to #{item.send(attribute_name)} to resolve duplicate issue"
      item.save
    end
  end
end

# Create a case-insensitive uniqueness constraint on the `tags` table's `name` field.
# This requires a resolution for renaming existing tags. If 'mytag' and 'MyTag' both
# exist in the database, this will rename 'MyTag' to 'MyTag1'.
Sequel.migration do
  up do
    extension(:constraint_validations)

    require_relative '../../lib/razor'
    require_relative '../../lib/razor/initialize'

    alter_table :tags do
      resolve_duplicates(Razor::Data::Tag, :name)

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
