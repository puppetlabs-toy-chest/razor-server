require 'sequel'
require 'logger'
require_relative 'config'

# Load Sequel extensions
Sequel.extension :core_extensions, :inflector
Sequel.extension :pg_array, :pg_array_ops
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
      @@database ||= Sequel.connect(Config["database_url"],
                                :loggers => [Razor.logger])
    end

    def logger
      @@logger ||= Logger.new(File::join(Razor.root, "log", "#{Razor.env}.log"))
    end

    def config
      Config.instance
    end
  end

  # Establish a database connection now and load extensions
  Razor.database
  Razor.database.extension :pg_array

  # Configure global model plugins; these require a database connection, so
  # much be established now that we have one.
  #
  # Infer, and extract, database constraints into the Ruby layer.  This makes
  # `valid?` and `errors` on model objects work much more nicely -- by reading
  # the database constraints and implementing them in Ruby automatically,
  # rather than by lifting all validation into the application.
  Sequel::Model.plugin :constraint_validations
  Sequel::Model.plugin :auto_validations
end
