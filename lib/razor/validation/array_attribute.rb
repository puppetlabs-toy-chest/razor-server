# -*- encoding: utf-8 -*-
class Razor::Validation::ArrayAttribute
  def initialize(index, checks = {})
    case index
    when Hash
      # If we got only a hash, and the default (empty) value for what to
      # check, then the user has said "entry ${checks}", and implies that they
      # want this to apply to all array elements.
      checks.empty? or raise TypeError, "index must be an integer or a range of integers"
      @range = 0 .. Float::INFINITY
      checks = index
    when nil
      @range = 0 .. Float::INFINITY
    when Integer
      index >= 0 or raise ArgumentError, "index #{index} must be at or above zero"
      @range = index .. index
    when Range
      (index.exclude_end? ? index.first < index.last : index.first <= index.last) or
        raise ArgumentError, "index does not contain any values!"
      index.first >= 0 or raise ArgumentError, "index must start at or above zero"

      @range = index
    else
      raise TypeError, "index must be an integer or a range of integers"
    end

    checks.is_a?(Hash) or raise TypeError, "must be followed by a hash"
    checks.each do |check, argument|
      respond_to?(check) or raise ArgumentError, "does not know how to perform a #{check} check"
      send(check, argument)
    end
  end

  def finalize(schema)
  end

  def validate!(value, index)
    # If that is not in our range, we just return to ignore it.
    return unless @range.include? index

    if @type
      Array(@type).any? do |check|
        # If we don't match the base type, go to the next one; if none match our
        # final validation failure will trigger and raise.
        next false unless value.class <= check[:type]

        # If there is a validation
        begin
          check[:validate] and check[:validate].call(value)
        rescue => e
          raise Razor::ValidationFailure, _("attribute at index %{index} fails type checking for %{type}: %{error}") % {index: index, type: ruby_type_to_json(check[:type]), error: e.to_s}
        end

        # If we got here we passed all the checks, and have a match, so we are good.
        break true
      end or raise Razor::ValidationFailure, n_(
        "attribute at position %{index} has wrong type %{actual} where %{expected} was expected",
        "attribute at position %{index} has wrong type %{actual} where one of %{expected} was expected",
        Array(@type).count) % {
        index:     index,
        actual:   ruby_type_to_json(value),
        expected: Array(@type).map {|x| ruby_type_to_json(x[:type]) }.join(', ')}
    end

    # If we have a nested schema, just throw the value into it to see if it
    # is valid.  That handles the nesting case nicely.
    if @nested_schema then @nested_schema.validate!(value) end

    return true
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

  def schema(schema)
    schema.is_a?(Razor::Validation::HashSchema) or
      schema.is_a?(Razor::Validation::ArraySchema) or
      raise ArgumentError, "schema must be a schema instance; use 'object' to define this"
    @nested_schema = schema
  end
end
