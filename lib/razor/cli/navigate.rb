require 'rest-client'
require 'json'

module Razor::CLI
  class Navigate

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      @doc = entrypoint
      @doc_url = parse.api_url
    end

    def last_url
      @doc_url
    end

    def entrypoint
      @entrypoint ||= json_get(@parse.api_url)
    end

    def collections
      entrypoint["collections"]
    end

    def commands
      entrypoint["commands"]
    end

    def query?
      collections.any? { |coll| coll["name"] == @segments.first }
    end

    def command(name)
      commands.find { |coll| coll["name"] == name }
    end

    def command?
      !! command(@segments.first)
    end

    def get_document
      if @segments.empty?
        entrypoint
      elsif query?
        @doc = collections
        while @segments.any?
          move_to @segments.shift
        end
        @doc
      elsif command?
        # @todo lutter 2013-08-16: None of this has any tests, and error
        # handling is heinous at best
        cmd, body = extract_command
        json_post(cmd["id"], body)
      else
        raise NavigationError.new(@doc_url, @segments, @doc)
      end
    end

    def extract_command
      cmd = command(@segments.shift)
      body = {}
      until @segments.empty?
        if @segments.shift =~ /\A--([a-z-]+)(=(\S+))?\Z/
          body[$1] = ($3 || @segments.shift)
        end
      end
      # Special treatment for tag rules
      if cmd["name"] == "create-tag" && body["rule"]
        body["rule"] = JSON::parse(body["rule"])
      end
      [cmd, body]
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

    def json_post(url, body)
      headers = {  :accept=>:json, "Content-Type" => :json }
      begin
        response = RestClient.post url, body.to_json, headers
      rescue Exception => e
        raise RequestError.new(url, e)
      end
      puts "POST #{url.to_s}\n#{body}\n-->\n#{response.body}" if @parse.dump_response?
      JSON::parse(response.body)
    end
  end
end
