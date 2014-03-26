# -*- encoding: utf-8 -*-
module Razor::Validation
  def self.included(base)
    raise "Razor::Validation should extend classes, not be included in them"
  end

  def __validations
    @validations ||= {}
  end

  def validate(command, &block)
    name = command.to_s.tr("_", "-")
    __validations[name] =
      Razor::Validation::DSL.build(name, block, Razor::Validation::HashSchema)
  end

  def validate!(command, data)
    if schema = __validations[command.to_s.tr("_", "-")]
      schema.validate!(data)
    end
  end
end

class Razor::ValidationFailure < TypeError
  def initialize(msg, status = 422)
    super(msg)
    @status = status
  end

  attr_reader 'status'
end

require_relative 'validation/dsl'
require_relative 'validation/hash_schema'
require_relative 'validation/hash_attribute'
require_relative 'validation/array_schema'
require_relative 'validation/array_attribute'

