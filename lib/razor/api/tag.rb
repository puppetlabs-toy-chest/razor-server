require 'json'

module Razor::API
  # The API transform for tag objects
  # 
  # An API tag follows the following format:
  #
  #     {
  #       "name": __tag_name__,
  #       "rule": [ ... ]
  #     }
  #
  # The value for the "rule" field follows the format found in Razor::Matcher.
  #
  # Here is an example of the tag format:
  #
  #     {
  #       "name": "virtual_machine",
  #       "rule": [
  #           "=",
  #           [
  #               "fact",
  #               "is_virtual"
  #           ],
  #           true
  #       ]
  #     }
  #
  class Tag < Transform
    
    def initialize(tag)
      @tag = tag
    end

    def to_hash
      return nil unless @tag

      {
        :name => @tag.name,
        :rule => @tag.rule
      }
    end
  end
end