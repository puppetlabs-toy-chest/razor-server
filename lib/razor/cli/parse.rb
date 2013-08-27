require 'uri'
require 'optparse'

module Razor::CLI

  class Parse
    def optparse
      OptionParser.new do |opts|
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

    def show_help?
      !!@option_help
    end

    def dump_response?
      !!@dump
    end

    attr_reader :api_url, :final_arguments

    def initialize(args)
      @api_url = URI.parse("http://localhost:8080/api")
      @args = args.dup
      navigate_args = optparse.order(args)
      if navigate_args.find {|x| /\A--help|-h\Z/ =~ x}
        @option_help = true
        @navigation_path = navigate_args.take_while {|x| /\A(?!-)/ =~ x}
        @final_arguments = []
      else
        @navigation_path = navigate_args.take_while {|x| /\A(?!-)/ =~ x}
        @option_help = @navigation_path.empty?
        @final_arguments = navigate_args.drop(@navigation_path.size)
      end
    end

    def navigate
      @navigate ||=Navigate.new(self, @navigation_path)
    end
  end
end
