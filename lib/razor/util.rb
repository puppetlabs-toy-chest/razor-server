# -*- encoding: utf-8 -*-
module Razor::Util; end

# Make this uniformly available.
class Object
  def ruby_type_to_json(ruby)
    # These should not be translated, since they are technical terms from the
    # JSON specification.
    case ruby
    when Hash    then 'object'
    when Array   then 'array'
    when String  then 'string'
    when Numeric then 'number'
    when true    then 'true'
    when false   then 'false'
    when nil     then 'null'
    # I don't believe we will ever, ever see this come up, but just in case...
    else _('unable to translate "%{name}" to JSON type') % {name: ruby.class.name}
    end
  end
end

require_relative 'util/template_config'
