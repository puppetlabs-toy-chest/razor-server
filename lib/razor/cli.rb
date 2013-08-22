module Razor
  module CLI
    class Error < RuntimeError; end

    class NavigationError < Error
      attr_reader :object
      def initialize(url, key, object)
        @key = key; @object= object
        if key.is_a?(Array)
          super "Could not navigate to '#{key.join(" ")}' from #{url}"
        else
          super "Could not find entry '#{key}' in object at #{url}"
        end
      end
    end
  end
end

require_relative 'cli/navigate'
require_relative 'cli/parse'
require_relative 'cli/format'
require_relative 'cli/siren'
