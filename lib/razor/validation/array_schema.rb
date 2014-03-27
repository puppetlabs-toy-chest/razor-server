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

  def validate!(data)
    # Ensure that we have the correct base data type, since nothing else will
    # work if we don't.
    data.is_a?(Array) or
      raise Razor::ValidationFailure, _('expected %{expected} but got %{actual}') %
      {expected: ruby_type_to_json(Array), actual: ruby_type_to_json(data)}

    # Validate that all our elements match our object schema, if we have one.
    data.each_with_index do |value, index|
      @checks.each do |check|
        check.validate!(value, index)
      end
    end
  end

  def object(index = nil, checks = {}, &block)
    block.is_a?(Proc)  or raise ArgumentError, "an object must have a block to define it"
    schema = Razor::Validation::HashSchema.build(@command, block)
    @checks << Razor::Validation::ArrayAttribute.new(index, checks.merge(schema: schema))
  end



  ########################################################################
  # Infrastructure for creating the a nested schema.
  class Builder < Object
    extend Forwardable

    def initialize(name)
      @name = name
    end

    def schema
      @schema ||= Razor::Validation::ArraySchema.new(@name)
    end

    def_delegators 'schema', *Razor::Validation::ArraySchema.public_instance_methods(false)
  end

  def self.build(name, block)
    Builder.new(name).tap{|i| i.instance_eval(&block) }.schema
  end
end
