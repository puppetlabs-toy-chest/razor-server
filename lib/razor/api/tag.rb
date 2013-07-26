require 'json'

module Razor::API
  # The API transform for tag objects
  # 
  # An API tag follows the following format:
  #
  #     {
  #       "name": __string__,
  #       "rule": [ ... ]
  #     }
  #
  # where
  # -  `"name"` is the name of the tag
  # -  `"rule"` follows the format found in Razor::Matcher. Generally, a rule
  #    is expressed as [ *operator*, *arg1*, *arg2*, ..., *argn* ] where
  #    *arg1-n* can be nested rules. See the example below for more
  #    information.
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