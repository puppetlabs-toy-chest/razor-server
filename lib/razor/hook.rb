# -*- encoding: utf-8 -*-
module Razor
  class HookRunFail < RuntimeError; end
  class HookInvalidJSON < ArgumentError; end
  class HookReturnError < ArgumentError; end

  class Hook
    attr_reader :event, :file, :status, :output
    
    def self.run_event_hooks(node, event)
      self.find_all_for_event(event).each do |hook|
        begin
          hook.run(node)
        rescue HookRunFail => e
          node.log_append({:severity => 'error', :msg => e.message})
        rescue HookReturnError => e
          node.log_append({:severity => 'error', :msg => e.message})
        rescue HookInvalidJSON => e
          node.log_append({:severity => 'error', :msg => e.message})
        end
      end
    end

    def self.find_all_for_event(event)
      hooks = []

      Razor.config.hook_paths.each do |hook_path|
        dirname = File::join(hook_path, event)
        if File.directory?(dirname)
          files = Dir.glob(File.join(dirname, '*')).select{|f| File.file?(f) and File.executable?(f)}
          files.each do |hook|
            hooks.push( new(hook, event) )
          end
        end
      end

      hooks
    end

    def initialize(hook, event)
      @event = event
      @file  = hook
    end

    def run(node)
      arg = node.to_hash.to_json

      #escape any ' in the arg for the shell.
      arg = arg.gsub(/'/, "\'")

      run_command( %Q[#{@file} '#{arg}'] )

      if @status == 0
        unless @output.empty?
          apply_metadata(node)
        end
      else
        raise HookRunFail, "Hook (#{@file}) produced exit code #{@status}.  Hooks must exit with 0 to be considered successfull"
      end
    end

    def run_command(command)
      save_output( %x| #{command} |.chomp ) 
      save_status( $?.exitstatus )
    end

    def apply_metadata(node)
      begin
          metadata = JSON.load(@output)
      rescue
        raise HookInvalidJSON, "Hook (#{@file}) produced malformed output. Hooks must generate no output or valid JSON"
      end

      if metadata
        metadata.is_a? Hash or
         raise HookReturnError, "Hook (#{@file}) returned data must be a hash"

        begin
          node.modify_metadata(metadata)
        rescue ArgumentError => e
          raise HookReturnError, "Hook (#{@file}) produced invalid metadata: #{e.message}"
        end
      end
    end
    
    def save_output(output)
      @output = output
      output
    end
    
    def save_status(status)
      @status = status
      status
    end
  end
end
