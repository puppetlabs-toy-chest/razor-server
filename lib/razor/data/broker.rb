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
end
