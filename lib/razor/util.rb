# -*- encoding: utf-8 -*-
module Razor::Util; end

# Make this uniformly available.
class Object
  def ruby_type_to_json(ruby)
    # We want to work with the class, not the instance.
    ruby = ruby.class unless ruby.is_a?(Module)

    # These should not be translated, since they are technical terms from the
    # JSON specification.
    if    ruby <= Hash       then 'object'
    elsif ruby <= Array      then 'array'
    elsif ruby <= String     then 'string'
    elsif ruby <= Numeric    then 'number'
    elsif ruby <= TrueClass  then 'true'
    elsif ruby <= FalseClass then 'false'
    elsif ruby <= NilClass   then 'null'
    elsif ruby <= URI        then 'string (URL)'
    # I don't believe we will ever, ever see this come up, but just in case...
    else _('unable to translate "%{name}" to JSON type') % {name: ruby.name}
    end
  end
end

require_relative 'util/template_config'
