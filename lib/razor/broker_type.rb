require 'erb'
require 'pathname'
require 'tilt'
require 'yaml'

# Signal that a broker was not found when requested by name.
class Razor::BrokerTypeNotFoundError < RuntimeError; end
class Razor::BrokerTypeInvalidError  < RuntimeError; end

class Razor::BrokerType
  # Enumerate all instances of brokers available on the system.
  def self.all
    Razor.config.broker_paths.collect do |path|
      # @todo danielp 2013-08-05: This just silently ignores regular files;
      # should we treat those differently by failing or something?
      #
      # We deliberately look through symlinks here, since that is pleasant
      # behaviour for both admins and developers.
      Pathname.glob(Pathname(path) + '*.broker').select(&:directory?)
    end.flatten.map {|p| p.basename('.broker').to_s }.uniq
  end

  # Fetch an instance of a single broker by name; this follows the
  # conventional path behaviour by preferring the first instance on the path.
  def self.find(name)
    broker = Razor.config.broker_paths.
      map  {|path| Pathname(path) + "#{name}.broker" }.
      find {|path| path.directory? }

    broker or raise Razor::BrokerTypeNotFoundError, "No broker #{name}.broker directory on search path"

    new(broker)
  end

  # The name of the broker
  def name
    @name
  end

  alias_method 'to_s', 'name'


  # Return the fully interpolated install script, ready to run on a node.
  #
  # @param node [Razor::Data::Node] the node instance to generate for.
  #
  # The node is directly exposed to the script, in case any data from it is
  # required, but only the broker metadata is exposed.
  #
  # @todo danielp 2013-08-09: this needs to pass the configuration data from
  # the in-database "instance" of the broker -- what was configured when the
  # user created the record that could be addressed from policy.
  def install_script(node)
    # While this is unlikely, if you could pass an arbitrary object here you
    # could theoretically exploit this to do bad things based on the
    # template actions.  Better safe than sorry...
    node.is_a?(Razor::Data::Node) or
      raise TypeError, "internal error: #{node.class} where Razor::Data::Node expected"

    # @todo danielp 2013-08-05: should we evaluate in an object context,
    # rather than a shiny new Object?  I don't imagine so, but...
    #
    # @todo danielp 2013-08-05: what else do we need to expose to the template
    # to make this all work?
    #
    # All objects passed to the template are frozen to avoid accidental
    # changes from user supplied code propagating back into the system.
    #
    # Users can certainly bypass this with minimal effort, deliberately made,
    # but it makes it much harder to accidentally change the system from
    # a template.
    #
    # This really is about protecting users from their own errors, not
    # protecting Razor from a deliberately malicious user.
    Tilt.new(install_template_path.to_s).render(
      # The namespace to work in: a new, blank, disconnected, immutable
      # object, to prevent users getting odd expectations or visibility into,
      # eg, our local scope.
      Object.new.freeze,
      # The local values to bind into the template follow, as a hash.
      :node => node.dup.freeze
    )
  end


  # Return the configuration metadata for this broker object; this is the
  # read-only data for use when configuring a new broker instance based of
  # this broker template.
  #
  # If there is no configuration data, returns the empty hash.
  def configuration_schema
    @configuration_schema ||= if configuration_path.exist?
                                YAML.load_file(configuration_path).freeze
                              else
                                {}.freeze
                              end
  end

  private
  # Create an in-memory proxy for the broker.  This is internal only; use the
  # `find` method to obtain a reference to a broker object.
  #
  # @param path [String] the path on disk to our broker definition.
  def initialize(path)
    @path = path
    @name = path.basename('.broker').to_s

    # The only mandatory part of the broker is the script to run on the node,
    # the `install.erb` file.  We assert nothing about it beyond the most
    # basic existence.
    install_template_path.exist? or
      raise Razor::BrokerTypeInvalidError, "#{@name} has no install template"
    install_template_path.readable? or
      raise Razor::BrokerTypeInvalidError, "#{@name} has an install template, but it is unreadable"
  end

  # Return the name of the installer template file.
  def install_template_path
    @path + 'install.erb'
  end

  def configuration_path
    @path + 'configuration.yaml'
  end
end
