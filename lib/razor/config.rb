# -*- encoding: utf-8 -*-
require 'singleton'
require 'yaml'

module Razor
  class InvalidConfigurationError < RuntimeError
    attr_reader :key
    def initialize(key, msg = _("setting is invalid"))
      super(_("entry %{key}: %{msg}") % {key: key, msg: msg})
      @key = key
    end
  end

  class Config
    # The config paths that templates have access to
    TEMPLATE_PATHS = [ "microkernel.debug_level", "microkernel.kernel_args",
                       "checkin_interval" ]

    # The possible keys we allow in hw_info,
    HW_INFO_KEYS = [ 'mac', 'serial', 'asset', 'uuid']

    def initialize(env, fname = nil)
      # Use the filename given, or from the environment, or from /etc if it
      # exists, otherwise the one in our root directory...
      fname ||= ENV["RAZOR_CONFIG"] ||
        (File.file?('/etc/razor/config.yaml') and '/etc/razor/config.yaml') ||
        File::join(File::dirname(__FILE__), '..', '..', 'config.yaml')

      # Save this for later, since we use it to find relative paths.
      @fname = fname

      begin
        yaml = File::open(fname, "r") { |fp| YAML::load(fp) } || {}
      rescue Errno::ENOENT
        raise InvalidConfigurationError,
          _("The configuration file %{filename} does not exist") % {filename: fname}
      rescue Errno::EACCES
        raise InvalidConfigurationError,
          _("The configuration file %{filename} is not readable") % {filename: fname}
      end
      @values = yaml["all"] || {}
      @values.merge!(yaml[Razor.env] || {})
    end

    def root
      File.dirname(@fname)
    end

    # Lookup an entry. To look up a nested value, you can pass in the
    # nested keys separated by a '.', so that passing "a.b" has the same
    # effect as +self["a"]["b"]+
    def [](key)
      key.to_s.split(".").inject(@values) { |v, k| v[k] if v }
    end

    def task_paths
      expand_paths('task')
    end

    def broker_paths
      expand_paths('broker')
    end

    def fact_blacklisted?(name)
      !! facts_blacklist_rx.match(name)
    end

    def validate!
      validate_facts_blacklist_rx
      validate_repo_store_root
      validate_match_nodes_on
    end

    private
    def expand_paths(what)
      option_name  = what + '_path' # eg: broker_path, task_path

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
        Regexp.compile("\\A((" + Array(self["facts.blacklist"]).map do |s|
                         if s =~ %r{\A/(.*)/\Z}
                           $1
                         else
                           Regexp.quote(s)
                         end
                       end.join(")|(") + "))\\Z")
    end

    # Validations
    def raise_ice(key, msg)
      raise InvalidConfigurationError.new(key, msg)
    end

    def validate_facts_blacklist_rx
      list = Array(self["facts.blacklist"])
      list.map { |s| s =~ %r{\A/(.*)/\Z} and $1 }.compact.each do |s|
        begin
          Regexp.compile(s)
        rescue RegexpError => e
          raise_ice("facts.blacklist",
                    _("entry %{raw} is not a valid regular expression: %{error}") % {raw: s, error: e.message})
        end
      end
    end

    def validate_repo_store_root
      key = 'repo_store_root'
      root = self[key] or
        raise_ice(key, _("must be set in the configuration file"))
      root = Pathname(root)
      root.absolute? or raise_ice key, _("must be an absolute path")
      root.directory? and root.writable? or
        raise_ice key, _("must be a writable directory")
    end

    def validate_match_nodes_on
      key = 'match_nodes_on'
      match_on = self[key] or
        raise_ice(key, _("must be set in the configuration file"))
      (match_on.is_a?(Array) and match_on.size > 0) or
        raise_ice(key, _("must be a nonempty array"))
      (match_on - HW_INFO_KEYS).empty? or
        raise_ice(key,
        _("must only contain '%{keys}'") % {keys: HW_INFO_KEYS.join("', '")})
    end
  end
end
