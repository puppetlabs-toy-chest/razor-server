require 'uri'
require 'optparse'

module Razor::CLI

  class Parse
    def get_optparse
      @optparse ||= OptionParser.new do |opts|
        opts.banner = "Usage: razor [FLAGS] NAVIGATION\n"
                      "   or: razor shell"

        opts.on "-d", "--dump", "Dumps API output to the screen" do
          @dump = true
        end

        opts.on "-U", "--url URL", "The full Razor API URL (default #{@api_url})" do |url|
          @api_url = URI.parse(url)
        end

        opts.on "-h", "--help", "Show this screen" do
          @option_help = true
        end

      end
    end

    def help
      output = get_optparse.to_s
      output << "\n    endpoints:\n"
      output << navigate.endpoints.map do |ref|
        next unless ref['id']
        "        #{ref["id"]} #{ref["desc"] || nil}"
      end.compact.join("\n")
    end

    def show_help?
      !!@option_help
    end

    def dump_response?
      !!@dump
    end

    attr_reader :api_url

    def initialize(args)
      @api_url = URI.parse("http://localhost:8080/api")
      @args = args.dup
      @options = get_optparse.parse!(args)
      if args.any?
        @navigation = args
      else
        @option_help = true
      end
    end

    def navigate
      @navigate ||=Navigate.new(self, @navigation)
    end
  end
end
