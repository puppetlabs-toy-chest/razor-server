# -*- encoding: utf-8 -*-
class Razor::Data::Broker < Sequel::Model

  one_to_many :policies
  one_to_many :events

  plugin :serialization, :json, :configuration

  serialize_attributes [
    ->(b){ b.name },               # serialize
    ->(b){ Razor::BrokerType.find(name: b) } # deserialize
  ], :broker_type

  # We have validation that we match our external files on disk, too.
  # While this isn't a complete promise, it does help catch some of the more
  # obvious errors.
  def validate
    super
    if broker_type.is_a?(Razor::BrokerType)
      # Validate our configuration -- now that we have access to our type to
      # obtain the schema for validation.
      schema = broker_type.configuration_schema

      # Extra keys found in the data we were given are treated as errors,
      # since they are most likely typos, or targetting a broker other than
      # the current broker.
      if configuration.is_a?(Hash)
        (configuration.keys - schema.keys).each do |additional|
          errors.add(:configuration, _("key '%{additional}' is not defined for this broker type") % {additional: additional})
        end
      else
        errors.add(:configuration, _("must be a Hash"))
      end

      # Required keys that are missing from the supplied configuration.
      schema.each do |key, details|
        next unless details['required']
        next if configuration.has_key? key
        errors.add(:configuration, _("key '%{key}' is required by this broker type, but was not supplied") % {key: key})
      end
    else
      errors.add(:broker_type, _("'%{name}' is not valid") % {name: broker_type})
    end
  end

  # This is the same hack around auto_validation as in +Node+
  def schema_type_class(k)
    case k
    when :configuration then Hash
    when :broker_type   then Razor::BrokerType
    else                     super
    end
  end

  # Provide access to the install script for this broker.  This is a shorthand
  # for loading the broker manually, and building the script by passing this
  # as the instance object.
  #
  # @param node [Razor::Data::Node] the node we are producing an install
  # script for.
  # @param script [String] the name of the resulting install script, excluding
  # its `.erb` extension. If this is omitted, it will look for `install.erb`
  #
  # @return [String] the compiled installation script, ready to run.
  def install_script_for(node, script = 'install')
    broker_type.install_script(node, self, script)
  end
end
