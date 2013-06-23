require 'singleton'
require 'yaml'

module Razor
  class Config
    include Singleton

    def initialize
      fname = ENV["RAZOR_CONFIG"] ||
        File::join(File::dirname(__FILE__), '..', '..', 'config.yaml')
      yaml = File::open(fname, "r") { |fp| YAML::load(fp) }
      @values = yaml["all"] || {}
      @values.merge!(yaml[Razor.env])
    end

    # Lookup an entry. To look up a nested value, you can pass in the
    # nested keys separated by a '.', so that passing "a.b" has the same
    # effect as +self["a"]["b"]+
    def [](key)
      key.to_s.split(".").inject(@values) { |v, k| v[k] if v }
    end

    def installer_paths
      self["installer_path"].split(":").map { |path|
        if path.start_with?("/")
          path
        else
          File::expand_path(File::join(Razor.root, path))
        end
      }
    end

    def self.[](key)
      config[key]
    end

    def self.config
      self.instance
    end
  end
end
