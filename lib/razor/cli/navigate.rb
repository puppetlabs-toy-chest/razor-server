require 'rest-client'
require 'json'

module Razor::CLI
  class Navigate

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      @doc = endpoints
      @doc_url = parse.api_url
    end

    def last_url
      @doc_url
    end

    def endpoints
      @endpoints ||= get_endpoints
    end

    def get_document
      while @segments.any?
        move_to @segments.shift
      end
      @doc
    end

    def move_to(key)
      key = key.to_i if key.to_i.to_s == key
      if @doc.is_a? Array
        obj = @doc.find {|x| x.is_a?(Hash) and x["name"] == key }
      elsif @doc.is_a? Hash
        obj = @doc[key]
      end

      raise NavigationError.new(@doc_url, key, @doc) unless obj

      if obj.is_a?(Hash) && obj["id"]
        @doc = json_get(obj["id"])
        @doc_url = obj["id"]
      elsif obj.is_a? Hash
        @doc = obj
      else
        @doc = nil
      end
    end

    def get(url, headers={})
      begin
        response = RestClient.get url.to_s, headers
      rescue Exception => e
        raise RequestError.new url, e
      end
      puts "GET #{url.to_s}\n#{response.body}" if @parse.dump_response?
      response
    end

    def json_get(url, headers = {})
      response = get(url,headers.merge(:accept => :json))
      unless response.headers[:content_type] =~ /application\/json/
       raise "Received content type #{response.headers[:content_type]}"
      end
      JSON.parse(response.body)
    end

    def get_endpoints
      json_get(@parse.api_url)["collections"]
    end

  end
end
