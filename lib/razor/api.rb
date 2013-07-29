# The classes in Razor::API serve as a wrapper around the persistence layer
# (Razor::Data) to provide a consistent API to Razor clients. This allows the
# internal implementation to introduce non-backwards-compatible changes while
# maintaining external compatability.

module Razor::API

  # Base class for persistent object to JSON API translators. Transformations
  # can be performed by calling Transform.to_hash(obj) or
  # Transform.new(obj).to_hash
  class Transform
    def self.to_json(obj)
      self.new(obj).to_json
    end

    def self.to_hash(obj)
      self.new(obj).to_hash
    end

    def to_json
      to_hash.to_json
    end
  end
end


require_relative 'api/tag.rb'
require_relative 'api/policy.rb'