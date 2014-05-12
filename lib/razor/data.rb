# -*- encoding: utf-8 -*-
# The persistence layer of Razor; these classes are the primary interface
# to the Database. Usually, these would be called 'models', but Razor uses
# the term to mean something else.
#
# This is also used as a plugin, to allow us to add behaviour across all our
# models uniformly.
module Razor::Data
  module ClassMethods
    def friendly_name
      name.split('::').last.scan(/[A-Z][^A-Z]*/).join(' ').downcase
    end

    # Import data from a command as a new object in the database; this has
    # some semantics tied specifically to our desired behaviour around
    # idempotent operations:
    #
    # * if there is no match in the database, create a new object
    # * if there is a match in the database, then:
    #   - if it is exactly identical (eg: same fields present, and same
    #     values) then return the obect
    #   - else raise a conflict error
    #
    # Specifically, if you submit a command, it matches all supplied fields,
    # but you include an additional optional field on either side, the result
    # is failure.
    #
    # This implements the generic logic for retries.  It should only need to
    # be overridden when the child is going to augment the behaviour, and
    # augmentation should happen *after* the super method is invoked, eg:
    #
    #    def self.import(data, command)
    #      super.tap do |instance, new|
    #        if new then instance.publish('do_something', command) end
    #      end
    #    end
    #
    # This returns the array [instance, new?], where instance is the instance
    # created or found, and new? is a truthy value indicating if this is a new
    # or an old instance.
    def import(data, command = nil)
      command.nil? or command.is_a?(Razor::Data::Command) or
        raise _('internal error: got %{type} where Razor::Data::Command expected') %
        {type: command.class}

      begin
        # We need a nested savepoint so that an insert constraint violation
        # doesn't abort our whole transaction.
        Razor.database.transaction(savepoint: true) do
          return create(data), true
        end
      rescue Sequel::UniqueConstraintViolation
        unless duplicate = find(name: data['name'])
          # Guess the duplicate was deleted during the race between failure and
          # recovery, so we can just retry the operation and have it succeed.
          Razor.logger.info(_(<<-MSG) % {self: self, data: data})
%{self}.create(%{data}) failed unique constraint, but missing duplicate, retrying
          MSG
          retry
        end

        # Is this an exact match for the existing repo, or is it different?
        #
        # We don't have a usable equality predicate in the model object, so
        # this open-codes the comparison here.  Perhaps we should make this
        # generic, but I would rather have at least one more example before we
        # do that.
        different = fields_for_command_comparison.reject do |key|
          duplicate.send(key) == data[key]
        end

        # If we found differences, we want to inform the user of them.
        if different.empty?
          # Just return the duplicate object, which will 202 for our user.
          return duplicate, false
        else
          msg = _('The %{what} %{name} already exists, and the %{conflict} fields do not match') % {what: friendly_name, name: data['name'], conflict: different.join(', ')}
          raise Razor::Conflict, msg
        end
      end
    end

    # Return the set of attribute names that are significant for comparison
    # when considering if two objects are identical.
    def fields_for_command_comparison
      (columns - Array(primary_key)).map(&:to_s)
    end
  end

  module InstanceMethods
    extend Forwardable
    def_delegators 'self.class', 'friendly_name'
  end
end

# Configure global model plugins; these require a database connection, so
# much be established now that we have one.
#
# Infer, and extract, database constraints into the Ruby layer.  This makes
# `valid?` and `errors` on model objects work much more nicely -- by reading
# the database constraints and implementing them in Ruby automatically,
# rather than by lifting all validation into the application.
Sequel::Model.plugin :constraint_validations
Sequel::Model.plugin :auto_validations

# Add a `publish` method to all Sequel::Model objects, allowing them to be
# sent messages through the TorqueBox message queue system.
Sequel::Model.plugin Razor::Messaging::Sequel::Plugin

# Add additional helper methods to all our models
Sequel::Model.plugin Razor::Data

require_relative 'data/task'
require_relative 'data/repo'
require_relative 'data/policy'
require_relative 'data/tag'
require_relative 'data/node_log_entry'
require_relative 'data/node'
require_relative 'data/broker'
require_relative 'data/command'
