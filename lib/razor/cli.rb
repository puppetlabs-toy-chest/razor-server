module Razor
  module CLI
    class Error < RuntimeError; end

    class NavigationError < Error
      def initialize(url, key, doc)
        @key = key; @doc = doc
        if key.is_a?(Array)
          super "Could not navigate to '#{key.join(" ")}' from #{url}"
        else
          super "Could not find entry '#{key}' in document at #{url}"
        end
      end
    end

    class RequestError < Error
      def initialize(url, ex = nil)
        super "error while retrieving '#{url}'" + (ex ? ": #{ex}" : "")
      end
    end
  end
end

require_relative 'cli/navigate'
require_relative 'cli/parse'
require_relative 'cli/format'
