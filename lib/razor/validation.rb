# -*- encoding: utf-8 -*-
module Razor::Validation; end

require_relative 'validation/hash_schema'
require_relative 'validation/hash_attribute'
require_relative 'validation/array_schema'
require_relative 'validation/array_attribute'

module Razor::Validation
  extend Forwardable

  def loading_complete
    super if defined?(super)
    schema.finalize
  end

  def schema
    @schema ||= Razor::Validation::HashSchema.new(name)
  end

  # Kind of cheap, but this should forward all the instance methods along, but
  # only if they are defined specifically on that class.
  def_delegators('schema', :array, :attr, :object, :require_one_of, :authz, :extra_attrs, :validate!)
end

class Razor::ValidationFailure < TypeError
  def initialize(msg, status = 422)
    super(msg)
    @status = status
  end

  attr_reader 'status'
end

