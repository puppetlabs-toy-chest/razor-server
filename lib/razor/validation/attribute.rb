# -*- encoding: utf-8 -*-
class Razor::Validation::Attribute
  def initialize(name, checks)
    name.is_a?(String) or raise TypeError, "attribute name must be a string"
    name =~ /\A[-a-z0-9]+\z/ or raise ArgumentError, "attribute name is not valid"
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

  def validate!(data)
    # if the key is not present, fail if required, otherwise we are done validating.
    unless data.has_key?(@name)
      @required and
        raise Razor::ValidationFailure, _("required attribute %{name} is missing") % {name: @name}
      return true
    end

    @exclude and @exclude.each do |what|
      data.has_key?(what) and
        raise Razor::ValidationFailure, _("if %{name} is present, %{exclude} must not be present") % {name: @name, exclude: what}

    @also and @also.each do |what|
        data.has_key?(what) or
          raise Razor::ValidationFailure, _("if %{name} is present, %{also} must also be present") % {name: @name, also: @also.join(', ')}
      end
    end

    value = data[@name]

    if @type and not value.class <= @type
      raise Razor::ValidationFailure, _("attribute %{name} has wrong type %{actual} where %{expected} was expected") % {
        name:     @name,
        actual:   ruby_type_to_json(value),
        expected: ruby_type_to_json(@type)}
    end

    begin
      @type_validate and @type_validate.call(value)
    rescue => e
      raise Razor::ValidationFailure, _("attribute %{name} fails type checking: %{error}") % {name: @name, error: e.to_s}
    end

    if @references
      @references[@refname => value] or
        raise Razor::ValidationFailure.new(_("attribute %{name} must refer to an existing instance") % {name: @name}, 404)
    end

    return true
  end

  def required(is)
    @required = !!is
  end

  def type(which)
    which.is_a?(Module) or raise ArgumentError, "type checks must be passed a class or module"

    if which <= URI
      @type = String
      @type_validate = -> str { URI.parse(str) }
    else
      @type = which
    end
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
    what.is_a?(Class) and what <= Sequel::Model or
      raise ArgumentError, "attribute references must be a Sequel::Model class"
    @references = what
    @refname    = @name.to_sym
  end
end
