# -*- encoding: utf-8 -*-
require 'set'
require 'forwardable'

class Razor::Validation::HashSchema
  def initialize(command)
    @command             = command
    @authz_template      = "\"commands:#{@command}\""
    @authz_dependencies  = []
    @attributes          = {}
    @extra_attr_patterns = {}
    @require_one_of      = []
  end

  # Perform any final checks that our content is sane, for things that could
  # be misordered in the DSL.
  def finalize
    @authz_dependencies.each do |attr|
      @attributes.has_key?(attr) or
        raise ArgumentError, "authz pattern references #{attr} but it is not defined"
    end

    @require_one_of.each do |assert|
      assert.each do |attr|
        @attributes.has_key?(attr) or
          raise ArgumentError, "require_one_of #{assert.sort.join(', ')} references #{attr} but it is not defined as an attribute"
      end
    end

    @attributes.each {|_, attr| attr.finalize(self) }
  end

  def attribute(name)
    @attributes[name]
  end

  def expand(path, attr = nil)
    path = [path, attr].compact.join('.')
    path.empty? and _('the command') or path
  end

  def validate!(data, path)
    checked = {}

    # Ensure that we have the correct base data type, since nothing else will
    # work if we don't.
    data.is_a?(Hash) or
      raise Razor::ValidationFailure,
        _('%{this} should be an object, but got %{actual}') %
        {this: expand(path), actual: ruby_type_to_json(data)}

    # Ensure that any dependencies of our authz system are satisfied.
    @authz_dependencies.each do |attr|
      next if checked[attr]
      checked[attr] = @attributes[attr].validate!(data, path)
    end

    # Perform the authz check itself.  Will raise on failure.  Only applied on
    # the top-level object to avoid duplicating tests all the way down.
    if path.nil? and @authz_template and Razor.config['auth.enabled']
      authz = eval(@authz_template)
      org.apache.shiro.SecurityUtils.subject.check_permissions(authz)
    end

    # Now, check any remaining attributes.
    @attributes.each do |attr, check|
      next if checked[attr]
      checked[attr] = check.validate!(data, path)
    end

    # Check if we have the minimum of multiple required, but not
    # present, attributes.
    @require_one_of.each do |assert|
      overlap = (data.keys & assert)
      if overlap.count == 0
        raise Razor::ValidationFailure, _('%{this} requires one out of the %{assert} attributes to be supplied') % {this: expand(path), assert: assert.sort.join(', ')}
      elsif overlap.count >= 2
        raise Razor::ValidationFailure, _('%{this} requires at most one of %{overlap} to be supplied') % {this: expand(path), overlap: overlap.sort.join(', ')}
      end
    end

    # Check to see if extra attributes are present.  Then we remove any that
    # are matched by our extra attribute patterns, and finally fail if there
    # are still more.
    extra_attributes = data.keys - @attributes.keys

    @extra_attr_patterns.each do |pattern, check|
      extra_attributes = extra_attributes.reject do |name|
        next false unless name =~ pattern
        check.validate!(data, path, name)
        true
      end
    end

    # Disallow any additional attributes.  If you didn't match something, we
    # reject you.
    unless extra_attributes.empty?
      msg = n_(
        'extra attribute %{extra} was present in %{this}, but is not allowed',
        'extra attributes %{extra} were present in %{this}, but are not allowed',
        extra_attributes.count) %
        {this: expand(path), extra: extra_attributes.sort.join(', ')}
      raise Razor::ValidationFailure, msg
    end
  end

  def authz(pattern)
    pattern.is_a?(String) or raise TypeError, "the authz pattern must be a string"
    pattern.empty? and raise ArgumentError, "the authz pattern must not be empty"
    pattern =~ /\A[-a-z%{}]+\z/ or raise "the authz pattern must contain only a-z, and attribute substitutions"

    # Compile the pattern into two things: one, the shiro string that matches
    # what we want to validate, and two, the set of dependent attributes that
    # we need to check before we can verify the authentication string.
    authz = pattern.gsub(/%{.*?}/) do |match|
      name = match[2..-2]
      unless name and name =~ /\A[a-z]+\z/
        raise "authz pattern substitution #{match.inspect} is invalid"
      end

      # Stash a reference to our dependencies so we can eval them first.
      @authz_dependencies << name

      # Emit a string that will evaluate using normal string substitution to a
      # reference to a member of the data object in current scope; we later
      # use that to create the specific authz matcher.
      '#{data[' + name.inspect + ']}'
    end

    # Replace the string-inna-string with a version including our extended
    # template, ready to check the details as well as the coarse permission.
    @authz_template = @authz_template[0..-2] + ':' + authz + '"'
  end

  def attr(name, checks = {})
    name.is_a?(String) or raise ArgumentError, "attribute name must be a string"
    @attributes[name] = Razor::Validation::HashAttribute.new(name, checks)
  end

  def object(name, checks = {}, &block)
    name.is_a?(String) or raise ArgumentError, "attribute name must be a string"
    block.is_a?(Proc)  or raise ArgumentError, "object #{name} must have a block to define it"
    @attributes[name] = Razor::Validation::HashAttribute.
      new(name, checks.merge(type: Hash, schema: self.class.build(name, block)))
  end

  def array(name, checks = {}, &block)
    name.is_a?(String) or raise ArgumentError, "attribute name must be a string"
    block ||= ->(*_) {}         # make it work without the block, just checks.

    schema = Razor::Validation::ArraySchema.build(name, block)
    @attributes[name] = Razor::Validation::HashAttribute.
      new(name, checks.merge(type: Array, schema: schema))
  end

  def require_one_of(*attributes)
    attributes.all? {|attr| attr.is_a?(String) } or
      raise ArgumentError, "required_one_of must be given a set of string attribute names"

    unless attributes.uniq == attributes
      set = Set.new
      duplicates = attributes.reject {|attr| set.add? attr }.uniq
      raise ArgumentError, "required_one_of #{attributes.join(', ')} includes duplicate elements #{duplicates.join(', ')}"
    end

    # append the array of attributes to the set to check, since each
    # invocation of this creates a new, independent assertion.
    @require_one_of << attributes
  end

  def extra_attrs(matches, checks = {})
    # One argument, and it is a hash, the user went directly to checks that
    # are applied to every single extra attribute found.
    if checks.empty? and matches.is_a?(Hash)
      checks = matches
      matches  = /./
    end

    checks.is_a?(Hash) or raise TypeError, "must be followed by a hash"

    Array(matches).flatten.each do |match|
      match.is_a?(Regexp) or
        raise ArgumentError, "extra_attrs must be given a regexp, or an array of the same"

      @extra_attr_patterns[match] = Razor::Validation::HashAttribute.new(match, checks)
    end

  end

  ########################################################################
  # Infrastructure for creating the a nested schema.
  class Builder < Object
    extend Forwardable

    def initialize(name)
      @schema = Razor::Validation::HashSchema.new(name)
    end

    attr_reader    'schema'
    def_delegators 'schema', *Razor::Validation::HashSchema.public_instance_methods(false)
  end

  def self.build(name, block)
    Builder.new(name).tap{|i| i.instance_eval(&block) }.schema
  end
end
