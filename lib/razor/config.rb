require 'singleton'
require 'yaml'

module Razor
  class Config
    include Singleton

    # The config paths that templates have access to
    TEMPLATE_PATHS = [ "microkernel.debug_level", "microkernel.kernel_args",
                       "checkin_interval" ]

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

    def broker_paths
      if self['broker_path']
        self['broker_path'].split(':').map do |path|
          path.empty? and next
          path.start_with?('/') and path or
            File::expand_path(File::join(Razor.root, path))
        end.compact
      else
        [File::expand_path(File::join(Razor.root, 'brokers'))]
      end
    end
  end
end
