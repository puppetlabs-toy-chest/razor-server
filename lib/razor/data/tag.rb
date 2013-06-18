class Razor::Data::Tag < Sequel::Model
  plugin :serialization, :json, :rule

  many_to_many :policies, :left_key => :tag_id, :right_key => :policy_id,
    :join_table => :policy_tag_mappings

  def match?(node)
    Razor::Matcher.new(rule).match?("facts" => node.facts)
  end

  def self.match(node)
    self.all.select { |tag| tag.match?(node) }
  end
end
