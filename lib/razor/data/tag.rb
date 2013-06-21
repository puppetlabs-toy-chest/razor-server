class Razor::Data::Tag < Sequel::Model
  plugin :serialization, :json, :rule

  many_to_many :policies

  def match?(node)
    Razor::Matcher.new(rule).match?("facts" => node.facts)
  end

  def self.match(node)
    self.all.select { |tag| tag.match?(node) }
  end
end
