module Razor
  require 'digest/md5'
  require 'fileutils'

  class MkUpdateNotFoundError < RuntimeError; end
  class MkUpdateInvalidError < RuntimeError; end

  class MkUpdate
     attr_reader :name, :version, :root_dir, :md5

    def initialize(name, metadata)
      unless metadata['root_dir']
        raise MkUpdateInvalidError, "MkUpdate #{name} does not have specify root_dir"
      end
      
      unless metadata['tar_file']
        raise MkUpdateInvalidError, "MkUpdate #{name} does not have a tar file"
      end
      
      @name     = name
      @version  = metadata['version'].to_s || '0'
      @root_dir = metadata['root_dir']
      @tar_file = metadata['tar_file']
      @md5      = Digest::MD5.hexdigest(tar)
    end

    def tar
      File.read(@tar_file)
    end

    def refresh
      @md5 = Digest::MD5.hexdigest(tar)
    end

    def self.find(name)
      if yaml = find_on_mkupdate_paths("#{name}.yaml")
        metadata = YAML::load(File::read(yaml)) || {}
        if tar_file = find_on_mkupdate_paths("#{name}.tar.gz")
          metadata['tar_file'] = tar_file
        end

        new(name, metadata)
      else
        raise MkUpdateNotFoundError, "No mkupdate #{name} exists"
      end
    end

    def self.all
      Razor.config.mkupdate_paths.map do |ip|
        Dir.glob(File::join(ip, "*.yaml")).map { |p| File::basename(p, ".yaml") }
      end.flatten.uniq.sort.map do |name|
        find(name)
      end
    end

    private
    def self.find_on_mkupdate_paths(*paths)
      Razor.config.mkupdate_paths.each do |ip|
        paths.each do |path|
          fname = File::join(ip, path)
          return fname if File::exists?(fname)
        end
      end
      nil
    end

    def logger
      @logger ||= TorqueBox::Logger.new(self.class)
    end
  end
end
