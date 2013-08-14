module Razor
  module CLI
    class Error < RuntimeError; end

    class NavigationError < Error
      def initialize(url, key, doc)
        @key = key; @doc = doc
        super "couldn't find ID or key '#{key}' for #{url}"
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
