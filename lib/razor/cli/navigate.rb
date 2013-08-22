require 'rest-client'
require 'json'

module Razor::CLI
  class Navigate

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      @entity = entrypoint
      @last_url = parse.api_url
    end

    attr_reader :last_url

    def entrypoint
      @entrypoint ||= siren_get @parse.api_url
    end

    def collections
      @entity["entities"] || []
    end

    def actions
      @entity["actions"] || []
    end

    def query(name)
      collections.find { |coll| (coll["properties"]||{})["name"] == name }
    end

    def query?
      !! query(@segments.first)
    end

    def action(name)
      actions.find { |coll| coll["name"] == name }
    end

    def action?
      !! action(@segments.first)
    end

    def get_final_entity
      if @segments.empty?
        @entity
      else
        while @segments.any?
          if query?
            # Follow the breadcrumbs to the next entity
            move_to @segments.shift
          elsif action?
            # Execute the action at the current location
            # @todo lutter 2013-08-16: None of this has any tests, and error
            # handling is heinous at best
            cmd, body = extract_action
            json_request(cmd["href"], cmd["method"], body)
          else
            raise NavigationError.new(@doc_url, @segments, @doc)
          end
        end
        @entity
      end
    end

    def extract_action
      raise "@todo alexkonradi 2013-08-20 Handle Siren commands"

      act = action(@segments.shift)
      body = {}
      until @segments.empty?
        if @segments.shift =~ /\A--([a-z-]+)(=(\S+))?\Z/
          body[$1] = ($3 || @segments.shift)
        end
      end
      # Special treatment for tag rules
      if act["name"] == "create-tag" && body["rule"]
        body["rule"] = JSON::parse(body["rule"])
      end
      body = JSON::parse(File::read(body["json"])) if body["json"]
      [act, body]
    end

    def self.find_entity(current, key)
      by_name = current["entities"].find do |ent|
        ent["properties"] and ent["properties"]["name"]==key
      end
      return by_name if by_name
    end

    def move_to(key)
      new_entity = query(key) or raise NavigationError.new(@doc_url, key, @entity)

      # Follow 'href' if it exists
      if new_entity["href"]
        @entity = siren_get(new_entity["href"])
        @last_url = new_entity["href"]
      else
        @entity = new_entity # Since sub-entities are themselves valid entities
      end
      @entity
    end

    def get(url, headers={})
      headers.merge! :accept => "application/vnd.siren+json"
      response = RestClient.get url.to_s, headers
      puts "GET #{url.to_s}\n#{response.body}" if @parse.dump_response?
      response
    end

    def siren_get(url, headers = {})
        response = get(url,headers.merge(:accept => "application/vnd.siren+json"))
      unless response.headers[:content_type] =~ /application\/(vnd.siren\+)?json/
       raise "Received content type #{response.headers[:content_type]}"
      end
      JSON.parse(response.body)
    end

    def json_request(url, method, body = nil)
      headers = { :accept => "application/vnd.siren+json", :content_type => :json }
      response = case method
      when "POST" then RestClient.post url, body.to_json, headers
      else raise Error.new "Can't handle method #{method}"
      end
      puts "#{method} #{url.to_s}\n#{body}\n-->\n#{response.body}" if @parse.dump_response?
      JSON::parse(response.body)
    end

  end
end
