# -*- encoding: utf-8 -*-
class Razor::Validation::HashAttribute
  def initialize(name, checks)
    case name
    when String
      name =~ /\A[-_a-z0-9]+\z/ or raise ArgumentError, "attribute name is not valid"
    when Regexp
      # no additional validation at this stage, but we should add some!
    else
      raise TypeError, "attribute name must be a string"
    end

    @name = name

    checks.is_a?(Hash) or raise TypeError, "must be followed by a hash"
    checks.each do |check, argument|
      respond_to?(check) or raise ArgumentError, "does not know how to perform a #{check} check"
      send(check, argument)
    end
  end

  def finalize(schema)
    Array(@exclude).each do |attr|
      schema.attribute(attr) or raise ArgumentError, "excluded attribute #{attr} by #{@name} is not defined in the schema"
    end

    Array(@also).each do |attr|
      schema.attribute(attr) or raise ArgumentError, "additionally required attribute #{attr} by #{@name} is not defined in the schema"
    end
  end

  def expand(path, name)
    [path, name].compact.join('.')
  end

  def validate!(data, path, name = @name)
    # if the key is not present, fail if required, otherwise we are done validating.
    unless data.has_key?(name)
      @required and
        raise Razor::ValidationFailure, _("%{this} is a required attribute, but it is not present") % {this: expand(path, name)}
      return true
    end

    @exclude and @exclude.each do |what|
      data.has_key?(what) and
        raise Razor::ValidationFailure, _("if %{this} is present, %{exclude} must not be present") % {this: expand(path, name), exclude: expand(path, what)}

    @also and @also.each do |what|
        data.has_key?(what) or
          raise Razor::ValidationFailure, _("if %{this} is present, %{also} must also be present") % {this: expand(path, name), also: @also.map{|x| expand(path, x)}.join(', ')}
      end
    end

    value = data[name]

    if @type
      Array(@type).any? do |check|
        # If we don't match the base type, go to the next one; if none match our
        # final validation failure will trigger and raise.
        next false unless value.class <= check[:type]

        # If there is a validation
        begin
          check[:validate] and check[:validate].call(value)
        rescue => e
          raise Razor::ValidationFailure, _("%{this} should be a %{type}, but failed validation: %{error}") % {this: expand(path, name), type: ruby_type_to_json(check[:type]), error: e.to_s}
        end

        # If we got here we passed all the checks, and have a match, so we are good.
        break true
      end or raise Razor::ValidationFailure, n_(
        "%{this} should be a %{expected}, but was actually a %{actual}",
        "%{this} should be one of %{expected}, but was actually a %{actual}",
        Array(@type).count) % {
        this:     expand(path, name),
        actual:   ruby_type_to_json(value),
        expected: Array(@type).map {|x| ruby_type_to_json(x[:type]) }.join(', ')}
    end

    if @references
      found = @references.find(@refname => value) rescue nil
      found or raise Razor::ValidationFailure.new(_("%{this} must be the %{match} of an existing %{target}, but is '%{value}'") % {this: expand(path, name), match: @refname, target: @references.friendly_name, value: value}, 404)
    end

    if @one_of
      @one_of.any? {|match| value == match } or
        raise Razor::ValidationFailure, _("%{this} must refer to one of %{valid}") % {this: expand(path, name), valid: @one_of.map {|x| x.nil? ? 'null' : x }.join(', ')}
    end

    # If we have a nested schema, just throw the value into it to see if it
    # is valid.  That handles the nesting case nicely.
    @nested_schema and @nested_schema.validate!(value, expand(path, name))

    return true
  end

  def required(is)
    @required = !!is
  end

  def type(which)
    which = Array(which)
    which.empty? and raise ArgumentError, "type checks must be passed some type to check"

    @type = which.map do |entry|
      case entry
      when nil    then {type: NilClass}
      when :bool  then [{type: TrueClass}, {type: FalseClass}]
      when Module then
        if entry <= URI then
          {type: String, validate: -> str { URI.parse(str) }}
        elsif entry <= Hash then
          {type: Hash, validate: -> hash { raise ArgumentError, "blank hash key not allowed" if hash.keys.include? '' }}
        else
          {type: entry}
        end
      else
        raise ArgumentError, "type checks must be passed a class, module, nil, or an array of the same (got #{which.inspect})"
      end
    end.flatten
  end

  def exclude(what)
    unless what.is_a?(String) or (what.is_a?(Array) and what.all?{|x| x.is_a?(String)})
      raise ArgumentError, "attribute exclusions must be a string, or an array of strings"
    end

    @exclude = Array(what)
  end

  def also(what)
    unless what.is_a?(String) or (what.is_a?(Array) and what.all?{|x| x.is_a?(String)})
      raise ArgumentError, "additional attribute requirements must be a string, or an array of strings"
    end

    @also = Array(what)
  end

  def references(what)
    const, key = what

    unless const.is_a?(Class) and const.respond_to?('find')
      raise ArgumentError, "attribute references must be a class that respond to find(key: value)"
    end

    @references = const
    @refname    = (key or @name).to_sym
  end

  ValidTypesForOneOf = [String, Numeric, TrueClass, FalseClass, NilClass]
  ValidTypesForOneOfJSON = ValidTypesForOneOf.map {|x| ruby_type_to_json(x) }.join(', ')
  def one_of(what)
    what.is_a? Array or
      raise ArgumentError, "one_of takes an array of options, not a #{ruby_type_to_json(what)}"
    what.each do |value|
      ValidTypesForOneOf.any? {|x| value.is_a? x } or
        raise ArgumentError, "one_of values must be one of #{ValidTypesForOneOfJSON}, not #{ruby_type_to_json(value)}"
    end

    what.uniq == what or raise ArgumentError, "one_of contains duplicate values"

    @one_of = what
  end

  def schema(schema)
    schema.is_a?(Razor::Validation::HashSchema) or
      schema.is_a?(Razor::Validation::ArraySchema) or
      raise ArgumentError, "schema must be a schema instance; use 'object' to define this"
    @nested_schema = schema
  end
end
