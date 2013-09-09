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

    def fact_blacklisted?(name)
      !! facts_blacklist_rx.match(name)
    end

    # @todo lutter 2013-09-08: validate the config on server startup and
    # produce useful error if anything is fishy. Things to validate:
    #   - facts.blacklist compiles to a valid regexp
    #   - image_store_root is an existing writable directory

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

    def facts_blacklist_rx
      @facts_blacklist_rx ||=
        Regexp.compile("\\A((" + self["facts.blacklist"].map do |s|
                         if s =~ %r{\A/(.*)/\Z}
                           $1
                         else
                           Regexp.quote(s)
                         end
                       end.join(")|(") + "))\\Z")
    end
  end
end
