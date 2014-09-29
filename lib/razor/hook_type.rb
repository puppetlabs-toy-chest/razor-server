# -*- encoding: utf-8 -*-
require 'pathname'
require 'yaml'

# Signal that a hook was not found when requested by name.
class Razor::HookTypeNotFoundError < RuntimeError; end
class Razor::HookTypeInvalidError  < RuntimeError; end

class Razor::HookType
  # Since we behave more or less like a Razor::Data object, we need to include
  # the same general purpose helper methods they do.
  extend  Razor::Data::ClassMethods
  include Razor::Data::InstanceMethods

  # Enumerate all instances of hooks available on the system.
  def self.all
    Razor.config.hook_paths.collect do |path|
      # @todo danielp 2013-08-05: This just silently ignores regular files;
      # should we treat those differently by failing or something?
      #
      # We deliberately look through symlinks here, since that is pleasant
      # behaviour for both admins and developers.
      Pathname.glob(Pathname(path) + '*.hook').select(&:directory?)
    end.flatten.map {|p| p.basename('.hook').to_s }.uniq
  end

  # Fetch an instance of a single hook by name; this follows the
  # conventional path behaviour by preferring the first instance on the path.
  #
  # This follows the pattern of our Sequel::Model classes to allow this to be
  # polymorphicly used in validation where they are.
  def self.find(match)
    match.keys == [:name] or raise ArgumentError, "hook types only match on `name`"
    name = match[:name]

    hook = Razor.config.hook_paths.
        map  {|path| Pathname(path) + "#{name}.hook" }.
        find {|path| path.directory? }

    hook ? new(hook) : nil
  end

  # The name of the hook
  def name
    @name
  end

  alias_method 'to_s', 'name'

  def ==(o)
    o.is_a?(Razor::HookType) && o.name == name
  end

  # Return the configuration metadata for this hook object; this is the
  # read-only data for use when configuring a new hook instance based of
  # this hook template.
  #
  # If there is no configuration data, returns the empty hash.
  def configuration_schema
    @configuration_schema ||= if configuration_path.exist?
                                YAML.load_file(configuration_path).freeze or {}
                              else
                                {}.freeze
                              end
  end

  private
  # Create an in-memory proxy for the hook.  This is internal only; use the
  # `find` method to obtain a reference to a hook object.
  #
  # @param path [String] the path on disk to our hook definition.
  def initialize(path)
    @path = path
    @name = path.basename('.hook').to_s
  end

  def configuration_path
    @path + 'configuration.yaml'
  end
end
