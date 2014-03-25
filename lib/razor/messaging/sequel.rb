# -*- encoding: utf-8 -*-
# This allows Ruby to parse the Razor::Messaging::Sequel class without
# Kernel::include-ing the ../../razor and ../../razor/initialize files.
# Loading those files here causes a race condition when trying to load the
# Razor::Data classes, which include parts of the Razor::Messaging::Sequel
# class, which isn't yet defined.
module Razor
  module Messaging
  end
end

require 'torquebox-messaging'

# A class to manage messages sent to individual Sequel::Model derived
# instances, used in conjugation with the Sequel plugin to implement the
# `publish` method on an instance.
class Razor::Messaging::Sequel < TorqueBox::Messaging::MessageProcessor
  include TorqueBox::Injectors

  # An exception class to represent an internal consistency check failure
  # when processing a message.  This is raised when there is no way a
  # message can ever be valid, due to some internal corruption or misuse.
  class MessageViolatesConsistencyChecks < RuntimeError
  end

  def initialize
    @logger = TorqueBox::Logger.new('razor.messaging.sequel')
  end

  # Handle receipt of a new message, destined for some instance or other of
  # a Sequel::Model derived class.  This validates the body, loads the
  # appropriate instance, and dispatches the embedded Ruby message to
  # the instance.
  #
  # @see #process_internal
  #
  # From a security perspective, this is a trusted method, operating on
  # trusted data: if you can forge messages handled by this receiver, you
  # can already mutate the state behind Razor in arbitrary ways; extending
  # that to other objects is not really especially interesting.
  #
  # That is to say: we assume the message body can be trusted, and that this
  # assumption is supported by the rest of our system.
  #
  # Despite that, we require that the class reside under the Razor::Data
  # namespace, and will fail any message that does not fit that rule.
  #
  # ## Message Format
  #
  # The body is assumed to be a Ruby Hash, containing only EDN preserved
  # content.  That includes strings, symbols, numbers, arrays, hashes, sets,
  # nil, Time, and boolean values.
  #
  # Required keys and their content are:
  # * `class`: the (Sequel::Model derived) Ruby class of the target instance.
  # * `instance`: the primary key hash of the target instance.
  # * `message`: the Ruby message to deliver to the target instance.
  # * `arguments`: an array of arguments, possibly empty, to deliver with
  #                the message.
  #
  # Optional keys - used primarily for error handling - are:
  # * `retries`: the integer number of retries that have been made for
  #              this message.
  # * `exceptions`: an array of exceptions that triggered the retries; these
  #                 are in the order that the exceptions occurred, so the
  #                 most recent error is the last entry in the array.
  #
  # The `exceptions` array contains a series of maps, keyed:
  # * `exception`: the name of the exception class
  # * `message`: the error string from the exception
  # * `backtrace`: an array of backtrace data from the exception
  #
  # ## Error Handling
  #
  # Unlike the default processor, we implement a truncated binary
  # exponential backoff algorithm in the face of potentially
  # recoverable errors.
  #
  # The hard-coded maximum retry count for a message is 16, and the maximum
  # delay exponent is 10, with a base backoff interval of 0.34 seconds.
  #
  # This gives a maximum possible backoff time of 4.26 minutes, but will
  # predominantly favour very short retry times, scaling up.  This should
  # give reasonably fast failure without over-burdening the system
  # reprocessing messages that will never succeed.
  #
  # The maximum wait for retry on all 16 steps is approximately:
  #
  #      1 => 0:01   7 =>  0:44  13 =>  5:48
  #      2 => 0:02   8 =>  1:27  14 =>  5:48
  #      3 => 0:03   9 =>  2:54  15 =>  5:48
  #      4 => 0:06  10 =>  5:48  16 =>  5:48
  #      5 => 0:11  11 =>  5:48
  #      6 => 0:22  12 =>  5:48
  #
  # The maximum possible wait time before declaring a message unsalvagable
  # is around 46:12, which seems a reasonable delay for external conditions
  # to clear up and allow successful processing.
  def process!(message)
    body = message.decode
    body.is_a? Hash or
      raise MessageViolatesConsistencyChecks, _("message body must be a map")
    body.has_key?('message') or
      raise MessageViolatesConsistencyChecks, _("message name must be present")

    class_constant = find_razor_data_class(body['class'])
    instance       = find_instance_in_class(class_constant, body['instance'])
    if body['command']
      # A command is optional for background processing
      command        = find_command(body['command'])
    end
    if instance.nil?
      # @todo danielp 2013-07-05: I genuinely don't know the correct way to
      # handle this.  For the moment we raise an error that will cause the
      # message to retry later, on the assumption that the object might come
      # into existence later -- some sort of XA transaction race or failure,
      # I guess, would be the root cause.
      #
      # Is that really the right strategy, though?
      raise _("Unable to find %{class} with pk %{pk}") %
        {class: class_constant.name, pk: body['instance'].inspect}
    else
      # We might as well be tolerant of our inputs, and treat a nil/missing
      # arguments value as "no arguments"
      args = Array(body['arguments'])
      args.unshift(command) if command
      instance.public_send(body['message'], *args)
    end

    # We don't have anything to send anyone at this point.
    return nil

  rescue Exception => exception
    # We don't care about the original body after we extend it with our
    # error handling data.
    if body.is_a? Hash
      body = update_body_with_exception(body, exception)
    else
      body = update_body_with_exception({'bad_message' => body}, exception)
    end

    if command
      command.add_exception(exception, body["retries"])
      command.save
    end

    queue = fetch('/queues/razor/sequel-instance-messages')

    if body["retries"] > 16 or exception.is_a?(MessageViolatesConsistencyChecks)
      # This message is dead, discard it.  That is done by simply returning
      # without putting another message on a queue.
      #
      # @todo danielp 2013-07-12: in future, we should probably use the dead
      # letter address, or an internal equivalent, to allow error handling.
      #
      # Sending to a DLQ should happen once we have some infrastructure,
      # probably including UI, to allow users to be alerted to those messages,
      # to browse them, and to take some meaningful action.  (eg: discard or
      # resend the message.)
      #
      # Alternately, perhaps we should deliver a configured message (eg:
      # message_failed) to the recipient class, with the details associated,
      # to allow custom error handling without having to build an entire new
      # queue and related infrastructure.
      #
      # After all, the point of such a message delivery would be to allow some
      # form of error recovery for the class, if it was even possible.
      @logger.warn("calling message #{message.getJMSMessageID} dead: #{exception}")
      @logger.debug("dead message #{message.getJMSMessageID} content as EDN: #{body.to_edn}")
      command.store('failed') if command
    else
      # Queue for a later retry.
      delay = delay_for_retry(body["retries"])
      @logger.info("retry message #{message.getJMSMessageID} after #{delay.round(2)}: #{exception}")

      queue.publish(body, :encoding => :edn, :scheduled => Time.now + delay)
    end
  end


  # Calculate the next delay for a given retry count.
  #
  # This is a truncated binary exponential backoff, with a base slot delay
  # of 0.34 seconds, and an exponent of min(retries, 10).
  #
  # @param retries [Integer] The retry count; we trust you to supply a value
  # greater than zero, and otherwise to be sane.
  #
  # @param prng [Random] The PRNG to use.  This is for testing purposes,
  # really, and you shouldn't pass a custom PRNG in production.
  def delay_for_retry(retries, prng = Random::DEFAULT)
    maximum_wait  = (2 ** [retries, 10].min) - 1
    slots_to_wait = prng.rand(0 .. maximum_wait)
    delay         = (0.34 * slots_to_wait).round(2)
  end

  # Annotate a message body with debugging and retry information.  This is
  # consumed later, either when the message is redelivered to our handler,
  # or when we touch on it in the dead letter queue later.
  #
  # This is not a destructive method, and the original body (and nested
  # elements) will be unmodified.
  #
  # We trust our caller to invoke us with a valid exception, since this is a
  # strictly internal helper method.  Except internal failures if that is
  # not respected.
  #
  # We also trust the caller to invoke us with a valid body, as a Hash, to
  # avoid too much duplication of logic around capturing the failure.
  #
  # @param body [Hash] the decoded body as received for processing.
  # @param exception [Exception] the exception to add to our message.
  #
  # @returns [Hash} a new body, with the the meta-data included.
  def update_body_with_exception(body, exception)
    body.merge(
      "retries"    => body.fetch("retries", 0) + 1,
      "exceptions" => Array(body["exceptions"]) + [{
          'exception' => exception.class.name,
          'message'   => exception.to_s,
          'backtrace' => exception.backtrace
      }]
    )
  end


  # Find a Razor data class, given the fully qualified name as input.
  #
  # This only works with normal classes assigned to a constant
  def find_razor_data_class(fullname)
    fullname.is_a? String or
      raise MessageViolatesConsistencyChecks, _("`class` must be a string")

    base, _, name = fullname.rpartition('::')

    base == 'Razor::Data' and not name.nil? and not name.empty? or
      raise MessageViolatesConsistencyChecks, _("%{name} is not under Razor::Data namespace") % {name: fullname.inspect}

    # rescue false handles incorrectly formatted constant names, such as ''
    # or 'foo', translating their error message into our permanent failure
    found = Razor::Data.const_defined?(name) rescue false
    found or raise MessageViolatesConsistencyChecks, _("%{name} is not a valid class name") % {name: fullname.inspect}

    constant = Razor::Data.const_get(name)
    constant.is_a?(Class) or raise MessageViolatesConsistencyChecks, _("%{name} is a %{class}, when Class was expected") % {name: fullname.inspect, class: constant.class}

    return constant
  end

  # Find an instance of a Sequel::Model given the class object, and the
  # primary key hash.
  def find_instance_in_class(class_constant, pk_hash)
    # @todo danielp 2013-07-05: technically, we could also use an array
    # lookup, but that is vulnerable to changes to the primary key of
    # a table.  While those shouldn't be common, I don't mind the little
    # extra weight required to make this more robust without proof that it
    # poses some longer-term problem.
    pk_hash.is_a?(Hash) or
      raise MessageViolatesConsistencyChecks, _("instance ID is %{pk}, when Hash was expected") % {pk: pk_hash.nil? ? 'nil' : pk_hash.class.name}

    # This is the recommended way to perform lookup according to the Sequel
    # docs, so we respect their wishes.
    class_constant[pk_hash]
  end

  # Find the Razor::Data::Command with the given primary key hash
  def find_command(pk_hash)
    pk_hash.is_a?(Hash) or
      raise MessageViolatesConsistencyChecks, _("command ID is %{pk}, when Hash was expected") % {pk: pk_hash.nil? ? 'nil' : pk_hash.class.name}
    pk_hash.empty? and
      raise MessageViolatesConsistencyChecks, _("command ID must be a nonempty Hash but is an empty Hash")
    command = Razor::Data::Command[pk_hash]
    command.nil? and
      raise MessageViolatesConsistencyChecks, _("Unable to find Razor::Data::Command with pk %{pk}") % {pk: pk_hash.inspect}
    return command
  end

  # A Sequel::Model plugin that integrates the `publish` method directly
  # into live instances of our classes.  This is a convenience method; see
  # `lib/razor/initialize.rb` for details of it being used.
  module Plugin
    # This module is mixed in as instance methods on all Sequel::Model
    # classes that include our plugin.
    module InstanceMethods
      include TorqueBox::Injectors

      # Publish a message to this Sequel::Model derived instance.
      # This behaves more or less like `Object#public_send`, with these
      # additional limitations:
      #
      # * the Sequel::Model instance is loaded fresh from the database
      #   before the message is delivered, and will not be the same object
      #   instance this method is called on.
      # * the message may be delivered in another thread.
      # * the message is delivered at some later time.
      # * the ordering of message deliver is not guaranteed.
      # * only fixed arity messages can be sent.
      #   - no varargs.
      #   - no optional arguments allowed.
      # * only EDN-safe arguments are permitted.
      #
      # EDN supports strings, symbols, numbers, arrays, hashes, sets, nil,
      # Time, and boolean values with full fidelity, so should preserve the
      # majority of reasonable arguments passed to a method.
      #
      # If an exception is thrown when the message is delivered, delivery
      # will be attempted again at a later time, until 16 attempts have been
      # made, or until it is finally successful.
      #
      # The return value of the message is ignored and discarded.
      #
      # There is no possible return value that will cause a message to be
      # redelivered at a later time -- raise an exception if you require that.
      #
      # @warning this method may block for up to 30 seconds waiting for
      # connection to the message queue service to be available.
      #
      # @param message   [String, Symbol] the message to deliver (see Object#public_send)
      # @param arguments [...] the arguments for the message (see
      #                  Object#public_send) If the first argument is a
      #                  Razor::Data::Command, the messaging machinery will
      #                  update it automatically with error messages if
      #                  there are any
      #
      # @return self, to allow chaining
      def publish(message, *arguments)
        block_given? and raise ArgumentError, _("blocks cannot be published")

        count = arguments.count
        command = arguments.shift if arguments.first.is_a?(Razor::Data::Command)
        message.is_a? String or message.is_a? Symbol or
          raise TypeError, _("message is a %{class} where String or Symbol was expected") % {class: message.class}

        # This will raise NameError if the message is not accepted locally,
        # which completes our contract of raising on error.
        arity = method(message).arity
        if arity < 0
          raise ArgumentError, _("variable number of arguments sending %{class}.%{message}") % {class: self.class, message: message}
            elsif arity != count
          raise ArgumentError, _("wrong number of arguments sending %{class}.%{message} (%{count} for %{arity}") % {class: self.class, message: message, count: count, arity: arity}
        end

        # Looks good, publish it; EDN encoding has reasonably good fidelity
        # for transmitting Ruby values over the wire, and this allows us to
        # enforce that during sending.
        msg = {
            'class'     => self.class.name,
            'instance'  => self.pk_hash,
            'message'   => message,
            'arguments' => arguments
        }
        if command
          command.store('pending') if command.id.nil?
          msg['command'] = command.pk_hash
        end
        fetch('/queues/razor/sequel-instance-messages').
          publish(msg, :encoding => :edn)

        return self
      end
    end
  end
end

# When TorqueBox loads message processors, it does so by loading this
# file directly -- in a new Ruby interpreter.  Given that, we need to ensure
# that our infrastructure is loaded.
#
# This is done *after* we define the code because it isn't actually dependent
# on any of the Razor code at parse time, and because we don't want to mess
# with load ordering when we are part of the Sinatra application...
require_relative '../initialize'
require_relative '../../razor'
