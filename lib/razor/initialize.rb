require 'sequel'
require 'logger'
require_relative 'config'

module Razor
  class << self
    def env
      @@env ||= ENV["RACK_ENV"]
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

  # Establish a database connection now
  Razor.database
end
