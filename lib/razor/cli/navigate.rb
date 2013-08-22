require 'rest-client'
require 'json'

module Razor::CLI
  class Navigate

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      self.current_object = entrypoint
      @last_url = parse.api_url
    end

    attr_reader :last_url

    def entrypoint
      @entrypoint ||= siren_get @parse.api_url
    end

    def current_object
      @entity
    end

    def current_object=(value)
      if value.is_a?(Razor::CLI::Siren::Entity) && value.href
        @entity = siren_get(value.href)
        @last_url = value.href
      else
        @entity = value
      end
    end

    def query(name)
      current_object.entities.find {|coll| coll.properties["name"] == name }
    end

    def next_is_query?
      !! query(@segments.first)
    end

    def action(name)
      current_object.actions.find { |action| action.name == name }
    end

    def next_is_action?
      !! action(@segments.first)
    end

    def get_final_object
      if @segments.empty?
        current_object
      else
        while @segments.any?
          path = current_object.path.dup << @segments.first
          if next_is_query?
            # Follow the breadcrumbs to the next entity
            self.current_object = query(@segments.shift)
            current_object.path = path
          elsif next_is_action?
            self.current_object = action(@segments.shift)
            current_object.path = path
            break # There's no point trying to navigate from an action
          else
            raise NavigationError.new(@last_url, @segments, current_object)
          end
        end
        current_object
      end
    end

    def execute_action(action, arguments)
      # Parse arguments into action.fields -> field.value
      body = extract_arguments(action, arguments)

      self.current_object = siren_request(action.url, action.method, body)
    end

    def extract_arguments(act, arguments)
      body = {}
      until arguments.empty?
        if arguments.shift =~ /\A--([a-z-]+)(=(\S+))?\Z/
          body[$1] = ($3 || arguments.shift)
        end
      end
      # Special treatment for tag rules
      if act.title == "Create a tag" && body["rule"]
        body["rule"] = JSON::parse(body["rule"])
      end
      body = JSON::parse(File::read(body["json"])) if body["json"]

      body
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

      Razor::CLI::Siren::Entity.parse(JSON.parse(response.body))
    end

    def siren_request(url, method, body = nil)
      headers = { :accept => "application/vnd.siren+json", :content_type => :json }
      response = case method
      when "POST" then RestClient.post url, body.to_json, headers
      else raise Error.new "Can't handle method #{method}"
      end
      puts "#{method} #{url.to_s}\n#{body}\n-->\n#{response.body}" if @parse.dump_response?
      Razor::CLI::Siren::Entity.parse(JSON::parse(response.body))
    end

  end
end
