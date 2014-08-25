# -*- encoding: utf-8 -*-
require 'set'

class Razor::Validation::ArraySchema
  def initialize(command)
    @command = command
    @checks  = []
  end

  # Perform any final checks that our content is sane, for things that could
  # be misordered in the DSL.
  def finalize
    @checks.each {|check| check.finalize(self) }
  end

  # Turn the schema into a markdown text string detailing ready to include in
  # our help.  This keeps responsibility for the internals of the schema
  # documentation inside the object; we just throw it raw into the help
  # template when required.
  HelpTemplate = ERB.new(_(<<-ERB), nil, '%')
% @checks.each do |check|
<%= check.help %>
% end
  ERB

  def help
    HelpTemplate.result(binding)
  end

  def validate!(data, path)
    # Ensure that we have the correct base data type, since nothing else will
    # work if we don't.
    data.is_a?(Array) or
      raise Razor::ValidationFailure, _('%{this} should be an array, but got %{actual}') %
      {this: path, actual: ruby_type_to_json(data)}

    # Validate that all our elements match our object schema, if we have one.
    data.each_with_index do |value, index|
      @checks.each do |check|
        check.validate!(value, path, index)
      end
    end
  end

  # This can be called as any of:
  # - Index/range plus checks Hash
  # - Index/range only
  # - Checks Hash only
  def object(index_or_checks = 0..Float::INFINITY, checks_or_nil = {}, &block)
    block.is_a?(Proc)  or raise ArgumentError, "an object must have a block to define it"
    schema = Razor::Validation::HashSchema.build(@command, block)
    @checks << Razor::Validation::ArrayAttribute.
      new(index_or_checks, checks_or_nil.merge(type: Hash, schema: schema))
  end

  def element(index_or_checks = 0..Float::INFINITY, checks_or_nothing = {})
    @checks << Razor::Validation::ArrayAttribute.new(index_or_checks, checks_or_nothing)
  end

  # This alias may be helpful for readability in cases where no index/range is provided.
  # That would indicate that the restriction applies to all elements, so you could achieve
  # the more readable: `elements type: String`.
  alias_method 'elements', 'element'

  ########################################################################
  # Infrastructure for creating the a nested schema.
  class Builder < Object
    extend Forwardable

    def initialize(name)
      @schema = Razor::Validation::ArraySchema.new(name)
    end

    attr_reader    'schema'
    def_delegators 'schema', *Razor::Validation::ArraySchema.public_instance_methods(false)
  end

  def self.build(name, block)
    Builder.new(name).tap{|i| i.instance_eval(&block) }.schema
  end
end
