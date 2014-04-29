# -*- encoding: utf-8 -*-
require 'set'
require 'forwardable'

class Razor::Validation::HashSchema
  def initialize(command)
    @command             = command
    @authz_template      = nil
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

  # Turn the schema into a markdown text string detailing ready to include in
  # our help.  This keeps responsibility for the internals of the schema
  # documentation inside the object; we just throw it raw into the help
  # template when required.
  HelpTemplate = ERB.new(_(<<-ERB), nil, '%')
<%= @help %>
% if @authz_template
# Access Control

This command's access control pattern: `<%= @authz_template %>`

% unless @authz_dependencies.empty?
Words surrounded by `%{...}` are substitutions from the input data: typically
the name of the object being modified, or some other critical detail, these
allow roles to be granted partial access to modify the system.

% end
For more detail on how the permission strings are structured and work, you can
see the [Shiro Permissions documentation][shiro].  That pattern is expanded
and then a permission check applied to it, before the command is authorized.

% auth = Razor.config['auth.enabled'] ? 'enabled' : 'disabled'
These checks only apply if security is enabled in the Razor configuration
file; on this server security is currently <%= auth %>.

[shiro]: http://shiro.apache.org/permissions.html

%end
% unless @attributes.empty?
# Attributes

%   @attributes.each do |name, attr|
 * <%= name %>
<%= attr.to_s %>
%   end
% end
  ERB

  def to_s
    HelpTemplate.result(binding)
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

    # Perform the authz check itself.  This also triggers a runtime failure if
    # the constraint "a toplevel schema must have an authz check" is violated,
    # since this is not trivial to resolve at compilation time.
    #
    # We could relocate this above the dependency check, but in the case where
    # we have no authz dependencies, there isn't much to gain by doing that;
    # the check above is a noop, and this concentrates the behaviour in the
    # correct location.
    if path.nil? and not @authz_template
      raise Razor::ValidationFailure, _(<<-EOT) % {this: expand(path)}
%{this} is a command, but has no access control information.
This is an internal error; please report it to Puppet Labs
at https://tickets.puppetlabs.com/
      EOT
    elsif @authz_template and Razor.config['auth.enabled']
      fields = @authz_dependencies.inject({}) do |hash, name|
        hash[name.to_sym] = data[name]
        hash
      end

      authz = @authz_template % fields

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
    if pattern.is_a?(String)
      pattern.empty? and raise ArgumentError, "the authz pattern must not be empty"

      pattern =~ /\A[-:a-z%{}]+\z/ or raise "the authz pattern must contain only a-z, attribute substitutions, or the : to separate hierarchy levels"
    elsif not pattern == true
      raise TypeError, "the authz pattern must be a string, or true"
    end

    # Stash away our template, and reset dependencies; if it is 'true' then we
    # just skip over the nested stuff, and accept that there is nothing other
    # than the base command to be tested.
    @authz_template     = "commands:#{@command}#{pattern == true ? '' : ':' + pattern}"
    @authz_dependencies = []

    # Compile the pattern into two things: one, the shiro string that matches
    # what we want to validate, and two, the set of dependent attributes that
    # we need to check before we can verify the authentication string.
    @authz_template.scan(/%{.*?}/) do |match|
      name = match[2..-2]
      unless name and name =~ /\A[a-z]+\z/
        raise "authz pattern substitution #{match.inspect} is invalid"
      end

      # Stash a reference to our dependencies so we can eval them first.
      @authz_dependencies << name
    end
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
