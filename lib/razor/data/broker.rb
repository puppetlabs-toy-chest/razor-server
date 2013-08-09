class Razor::Data::Broker < Sequel::Model
  plugin :serialization, :json, :configuration

  serialize_attributes [
    ->(b){ b.name },               # serialize
    ->(b){ Razor::BrokerType.find(b) } # deserialize
  ], :broker_type

  # We have validation that we match our external files on disk, too.
  # While this isn't a complete promise, it does help catch some of the more
  # obvious errors.
  def validate
    super
    broker_type.is_a?(Razor::BrokerType) or errors.add(:broker_type, "'#{broker_type}' is not valid")
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
  #
  # @return [String] the compiled installation script, ready to run.
  def install_script_for(node)
    broker_type.install_script(node, self)
  end
end
