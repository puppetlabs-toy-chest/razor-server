# -*- encoding: utf-8 -*-
class Razor::Validation::ArrayAttribute
  # Method optionally receives a Hash with keys:
  # - index: Can be an Integer, Range, or Nil (all, default), specifying to what the attribute applies.
  # - checks: Contains all checks applied to the attribute.
  def initialize(index_or_checks = 0..Float::INFINITY, checks_or_nothing = {})
    index, checks =
        if index_or_checks.is_a?(Hash)
          checks_or_nothing.empty? or
            raise TypeError, 'index must be an integer or a range of integers'

          [0..Float::INFINITY, index_or_checks]
        else
          [(index_or_checks or 0..Float::INFINITY), (checks_or_nothing or {})]
        end
    case index
    when Integer
      index >= 0 or raise ArgumentError, "index #{index} must be at or above zero"
      @range = index .. index
    when Range
      (index.exclude_end? ? index.first < index.last : index.first <= index.last) or
        raise ArgumentError, "index does not contain any values!"
      index.first >= 0 or raise ArgumentError, "index must start at or above zero"

      @range = index
    else
      raise TypeError, "index must be an integer or a range of integers, got #{index.class.inspect}"
    end

    checks.is_a?(Hash) or raise TypeError, "must be followed by a hash"
    checks.each do |check, argument|
      respond_to?(check) or raise ArgumentError, "does not know how to perform a #{check} check"
      send(check, argument)
    end
  end

  def finalize(schema)
  end

  # Documentation generation for the attribute.
  HelpTemplate = ERB.new(_(<<-ERB), nil, '%')
- <%= @help %>
- This must be an array.
% if @type
- <%= index_to_s %> must be of type <%= ruby_type_to_json(@type[:type]) %>.
% end
% if @references
- <%= index_to_s %> must match the <%= @refname %> of an existing <%= @references.friendly_name %>.
% end
% if @nested_schema
- <%= index_to_s %>:
<%= @nested_schema.to_s.gsub(/^/, '   ') %>
% end
  ERB

  def to_s
    # We indent so that nested attributes do the right thing.
    HelpTemplate.result(binding).gsub(/^/, '   ')
  end

  def index_to_s
    if Float(@range.max).infinite? and @range.min <= 0
      _("All elements")
    elsif Float(@range.max).infinite?
      _("Elements from %{min} onward") % {min: @range.min}
    else
      _("Elements from %{min} to %{max}") %
        {min: @range.min, max: @range.max}
    end
  end

  def expand(path, index)
    "#{path}[#{index}]"
  end

  def validate!(value, path, index)
    # If that is not in our range, we just return to ignore it.
    return unless @range.include? index

    if @type
      # If we don't match the base type, go to the next one; if none match our
      # final validation failure will trigger and raise.
      raise Razor::ValidationFailure, _("%{this} should be a %{expected}, but was actually a %{actual}") % {
          this:     expand(path, index),
          actual:   ruby_type_to_json(value),
          expected: ruby_type_to_json(@type[:type])} unless Array(@type[:type]).any? { |_| value.class <= _ }

      # If there is a validation
      begin
        @type[:validate] and @type[:validate].call(value)
      rescue => e
        raise Razor::ValidationFailure, _("%{this} should be a %{type}, but failed validation: %{error}") % {this: expand(path, index), type: ruby_type_to_json(@type[:type]), error: e.to_s}
      end
    end

    if @references
      found = @references.find(@refname => value) rescue nil
      found or raise Razor::ValidationFailure.new(_("%{this} must be the %{match} of an existing %{target}, but is '%{value}'") % {this: expand(path, index), match: @refname, target: @references.friendly_name, value: value}, 404)
    end

    # If we have a nested schema, just throw the value into it to see if it
    # is valid.  That handles the nesting case nicely.
    if @nested_schema then @nested_schema.validate!(value, expand(path, index)) end

    return true
  end

  def type(which)
    which.nil? and raise ArgumentError, "type checks must be passed some type to check"

    @type = case which
      when nil    then {type: NilClass}
      when :bool  then {type: [TrueClass, FalseClass]}
      when Module then
        if which <= URI then
          {type: String, validate: -> str { URI.parse(str) }}
        elsif which <= Hash then
          {type: Hash, validate: -> hash { raise ArgumentError, "blank hash key not allowed" if hash.keys.include? '' }}
        else
          {type: which}
        end
      else
        raise ArgumentError, "type checks must be passed a class, module, or nil (got #{which.inspect})"
    end
  end

  def schema(schema)
    schema.is_a?(Razor::Validation::HashSchema) or
      schema.is_a?(Razor::Validation::ArraySchema) or
      raise ArgumentError, "schema must be a schema instance; use 'object' to define this"
    @nested_schema = schema
  end

  def references(what)
    const, key = what

    unless const.is_a?(Class) and const.respond_to?('find')
      raise ArgumentError, "attribute references must be a class that respond to find(key: value)"
    end

    @references = const
    @refname    = (key or :name).to_sym
  end
end
