class Razor::Data::Tag < Sequel::Model
  plugin :serialization

  serialize_attributes [
    ->(m) { m.serialize },
    ->(m) { Razor::Matcher.unserialize(m) }
  ], :matcher


  many_to_many :policies

  def match?(node)
    matcher.match?("facts" => node.facts)
  end

  def self.match(node)
    self.all.select { |tag| tag.match?(node) }
  end

  # This is the same hack around auto_validation as in +Node+
  def schema_type_class(k)
    case k
    when :matcher then Razor::Matcher
    else super
    end
  end

  def validate
    super
    unless matcher.nil?
      if matcher.is_a?(Razor::Matcher)
        errors[:matcher] = matcher.errors unless matcher.valid?
      else
        errors.add(:matcher, "is not a matcher object")
      end
    end
  end
end
