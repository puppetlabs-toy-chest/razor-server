# -*- encoding: utf-8 -*-
require 'forwardable'

# Error used to signal a logical conflict in the change a command requests,
# and the current state of the system.  Maps to HTTP 409 status code if raised
# through the web application.
class Razor::Conflict < RuntimeError; end


# Define the base class for a command.  This encapsulates the active part, and
# the metadata of, any individual command we support.  Since these are a
# fairly fundamental part of our application domain, they get all sorts of
# magic and convention-over-configuration applied to them; this is where the
# magic is made to happen.
class Razor::Command
  extend Forwardable
  extend Razor::Validation
  extend Razor::Help

  ########################################################################
  # Command runtime interface, used on instances

  # Handle a raw HTTP POST request from the web interface, and translate it
  # into the internal command execution.  Nominally a command could override
  # this, but that makes little sense -- instead, the `#run` method should be
  # overridden.
  def handle_http_post(app)
    data = app.json_body
    data.is_a?(Hash) or
        raise Razor::ValidationFailure, _('expected %{expected} but got %{actual}') %
            {expected: ruby_type_to_json(Hash), actual: ruby_type_to_json(data)}
    old_data = data.to_json
    data = self.class.conform!(data)
    unless data.class <= Hash
      raise _(<<-ERR) % {class: self.class, type: data.class, body: old_data.inspect}
Internal error: Please report this to JIRA at http://jira.puppetlabs.com/
`%{class}.conform!` returned unexpected class %{type} instead of Hash
Body is: '%{body}'
      ERR
    end

    self.class.validate!(data, nil)

    @command = Razor::Data::Command.start(name, data.dup, app.user.principal)

    # @todo danielp 2014-03-26: the magic here feels kind of arbitrary, but
    # replicates current behaviour, so I guess it is correct enough.
    #
    # Also, we pass the app because the Sinatra application object happens to
    # reflect the sort of API we want for request handling (eg: halt, error),
    # but we may want to change it in future.  Hence the name change once you
    # get into the actual `run` function.
    result = run(app, data)
    result = app.view_object_reference(result) unless result.is_a?(Hash)
    @command.store
    result[:command] = app.view_object_url(@command)
    [202, result.to_json]
  end

  # This method is overridden in subclasses to change data such that it meets
  # current standards.
  def self.conform!(data)
    data
  end

  # This is a convenience method for adding aliases between two hashes. It
  # will remove any references to the alias in `data`, merging it with the
  # object in `real_attribute`. Data for both `real_attribute` and
  # `alias_name` will be ignored if not `nil` or a Hash.
  def self.add_hash_alias(data, real_attribute, alias_name)
    self.add_alias(data, real_attribute, alias_name, Hash, {}) do |first, second|
      first.merge(second)
    end
  end

  # This is a convenience method for adding aliases between two arrays. It
  # will remove any references to the alias in `data`, merging it with the
  # object in `real_attribute`. Data for both `real_attribute` and
  # `alias_name` will be ignored if not `nil` or an Array.
  def self.add_array_alias(data, real_attribute, alias_name)
    self.add_alias(data, real_attribute, alias_name, Array, []) do |first, second|
      first + second
    end
  end

  def self.add_alias(data, real_attribute, alias_name, clazz, default)
    data[alias_name] = default if data[alias_name].nil?
    data[real_attribute] = default if data[real_attribute].nil?

    if data[alias_name].is_a?(clazz) and data[real_attribute].is_a?(clazz)
      data[real_attribute] = yield data[real_attribute], data.delete(alias_name)
    end
  end

  # Handle execution of the command.  We have already decoded and validated
  # the input, and are confident that it meets our internal API requirement to
  # be used for operation.
  #
  # However, command-specific semantics such as conflict resolution must still
  # be handled in this code.
  def run(request, data)
    request.halt 500, _('internal error: command %{name} has no execution code!') % {name: name}
  end


  # Handle a raw HTTP get.  This formats metadata about the command into a
  # form that can be consumed by the client on the other end of the API.
  def handle_http_get(app)
    # This will stop processing if the client has a cached version identical
    # to our own.  The only time this may pose an issue is for a developer who
    # is actively editing the server-side content, without committing changes.
    app.etag "server-version-#{Razor::VERSION}"
    app.content_type 'application/json'

    {
      name: name,
      help: self.class.help,
      schema: self.class.schema
    }.to_json
  end


  # @todo danielp 2014-03-31: I feel awkward about this being defined here, as
  # well as up in the app, but without both knowing about it we end up in a
  # world where we can't dynamically add commands to, eg, the dispatch layer.
  #
  # This probably isn't a big thing in release code, but makes testing vastly
  # more painful and annoying than it otherwise has to be.
  def self.http_path
    "/api/commands/#{name}"
  end

  def self.to_command_list_hash
    {
      "name" => name,
      "rel"  => Razor::View::spec_url("commands", name),
      "id"   => http_path
    }.freeze
  end

  ########################################################################
  # The metaprogramming magic.  Here be dragons.

  # Return all the defined command objects -- the classes, not the instances.
  def self.all
    @commands ||= []
  end

  # Find a command; at the moment, only by name.
  def self.find(query = {})
    query.keys == [:name] or
      raise ArgumentError, "unsuppored command find for #{(query.keys - [:name]).join(', ')}"
    @commands.find {|c| c.name == query[:name] }
  end

  # When a derived class is created, we register it with our table of
  # commands, so that it can be found in future.  Warning: this triggers when
  # the class is opened, not closed, so *NOTHING* will be present in the
  # derived class at the time this hook fires.
  def self.inherited(by)
    super
    all << by
  end

  # This is fired in this file after all the derived classes are loaded, and
  # is hooked by modules to ensure that they can, eg, validate that all the
  # data they need has been added correctly, and so forth.
  def self.loading_complete
    super if defined?(super)
  end

  # Return the name of the command
  def self.name
    @name ||= super.split('::').last.
      scan(/[A-Z]+[^A-Z]*/).
      # Handle "IPMICredentials", where the additional split should be just
      # before the final capital letter.
      map {|s| s.gsub(/([A-Z]+)([A-Z]+[^A-Z])/, '\1-\2') }.
      map(&:downcase).join('-')
  end
  def_delegators 'self.class', 'name'
end

# Load all the commands!
Pathname.glob(Pathname(__FILE__).dirname + 'command' + '*.rb').each do |file|
  require_relative file
end

# ...and let them know that they are fully defined, so the can validate their
# validations, documentation, and other things.  Ideally Ruby would have given
# us some mechanism that fired when a class definition closed, but whatevs.
Razor::Command.all.map(&:loading_complete)
