# -*- encoding: utf-8 -*-
module Razor::Util; end

# Make this uniformly available.
class Object
  def ruby_type_to_json(instance)
    # We want to work with the class, not the instance.
    ruby = instance.is_a?(Module) ? instance : instance.class

    # These should not be translated, since they are technical terms from the
    # JSON specification.
    if instance == [TrueClass, FalseClass] then 'boolean'
    elsif ruby <= Hash       then 'object'
    elsif ruby <= String     then 'string'
    elsif ruby <= Numeric    then 'number'
    elsif ruby <= TrueClass  then 'boolean'
    elsif ruby <= FalseClass then 'boolean'
    elsif ruby <= Array      then 'array'
    elsif ruby <= NilClass   then 'null'
    elsif ruby <= URI        then 'string (URL)'
    # I don't believe we will ever, ever see this come up, but just in case...
    else _('unable to translate "%{name}" to JSON type') % {name: ruby.name}
    end
  end
end

require_relative 'util/template_config'
