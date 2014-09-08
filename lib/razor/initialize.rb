# -*- encoding: utf-8 -*-
require_relative 'gettext_setup'

require 'sequel'
require 'torquebox/logger'
require_relative 'config'

require 'monitor'

require 'java'
require_relative '../../jars/shiro-core-1.2.3.jar'
require_relative '../../jars/commons-beanutils-1.8.3.jar'

# Load Sequel extensions
Sequel.extension :core_extensions, :inflector
Sequel.extension :pg_array_ops
require 'sequel/plugins/serialization'

module Razor
  extend MonitorMixin

  class << self
    def env
      synchronize do
        @@env ||= ENV["RACK_ENV"] || "development"
      end
    end

    def root
      synchronize do
        @@root ||= File::expand_path(File::join(File::dirname(__FILE__), "..", ".."))
      end
    end

    def database
      synchronize do
        @@database ||= Sequel.connect(Razor.config["database_url"],
          :loggers => [TorqueBox::Logger.new("razor.sequel")])
      end
    end

    def database_is_current?
      @@database_migration_path ||= File.join(root, 'db', 'migrate')
      Sequel::Migrator.is_current?(database, @@database_migration_path)
    end

    def logger
      synchronize do
        @@logger ||= TorqueBox::Logger.new("razor")
      end
    end

    def config
      synchronize do
        @@config ||= Config.new(env)
      end
    end

    def security_manager
      synchronize do
        path = File.expand_path(Razor.config['auth.config'] || 'shiro.ini', config.root)
        unless defined?(@@security_manager_from) and @@security_manager_from == path
          @@security_manager_from = path
          @@security_manager = synchronize do
            # Make available an application-specific SecurityManager, to make the
            # authentication magic work.  In future we should consider replacing
            # this with a thread-per-request local, or even our own, to integrate
            # nicely with the model ... but this will do, for now.  I hope.
            logger.info("about to create the shiro factory from #{path}")
            factory = org.apache.shiro.config.IniSecurityManagerFactory.new(path)
            logger.info("about to create the security manager")
            factory.get_instance
          end
        end
        @@security_manager
      end
    end
  end

  Razor.config.validate!

  # Establish a database connection now and load extensions
  Razor.database
  Razor.database.extension :pg_array

  # Ensure the migration extension is available, now that we use it as part of
  # each request to ensure that we catch missed migrations correctly.
  Sequel.extension :migration

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
