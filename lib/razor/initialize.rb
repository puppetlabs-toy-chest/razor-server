require 'sequel'
require 'torquebox/logger'
require_relative 'config'

# Load Sequel extensions
Sequel.extension :core_extensions, :inflector
Sequel.extension :pg_array_ops
require 'sequel/plugins/serialization'

module Razor
  class << self
    def env
      @@env ||= ENV["RACK_ENV"] || "development"
    end

    def root
      dir = File::dirname(__FILE__)
      @@root ||= File::expand_path(File::join(dir, "..", ".."))
    end

    def database
      @@database ||= Sequel.connect(Razor.config["database_url"],
                       :loggers => [TorqueBox::Logger.new("razor.sequel")])
    end

    def logger
      @@logger ||= TorqueBox::Logger.new("razor")
    end

    def config
      @@config ||= Config.new(env)
    end
  end

  Razor.config.validate!

  # Establish a database connection now and load extensions
  Razor.database
  Razor.database.extension :pg_array

  # Ensure that we raise on ORM failures by default; while this is the default
  # in sufficiently recent versions of Sequel, it is better explicit than
  # implicit, especially because a missed check could spell disaster!
  Sequel::Model.raise_on_save_failure = true
  Sequel::Model.raise_on_typecast_failure = true

  # Also require that UPDATE or DELETE modify exactly one row when related to
  # a model object, ensuring that we don't have surprise missed changes
  # by default.  (In the face of concurrency, you may wish to suppress this
  # check manually during the individual operation, having reasoned out the
  # potential downsides of doing so.)
  Sequel::Model.require_modification = true

  # Require that unknown parameters passed to the model cause a failure,
  # rather than being silently ignored.
  Sequel::Model.strict_param_setting = true

  # Make all model subclass instances set defaults
  Sequel::Model.plugin :defaults_setter
end
