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
      expand_paths('installer')
    end

    def broker_paths
      expand_paths('broker')
    end

    private
    def expand_paths(what)
      option_name  = what + '_path' # eg: broker_path, installer_path

      if self[option_name]
        self[option_name].split(':').map do |path|
          path.empty? and next
          path.start_with?('/') and path or
            File::expand_path(File::join(Razor.root, path))
        end.compact
      else
        [File::expand_path(File::join(Razor.root, what.pluralize))]
      end
    end
  end
end
