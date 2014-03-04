# -*- encoding: utf-8 -*-
require 'forwardable'
require_relative 'hash_schema'

class Razor::Validation::DSL
  extend Forwardable

  def self.build(name, block)
    builder  = new
    instance = Razor::Validation::HashSchema.new(name)

    builder.instance_variable_set('@instance', instance)
    builder.instance_eval(&block)

    instance.finalize
    instance
  end

  # Kind of cheap, but this should forward all the instance methods along, but
  # only if they are defined specifically on that class.
  def_delegators('@instance', *Razor::Validation::HashSchema.public_instance_methods(false))
end
