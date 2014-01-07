module Razor
  require 'digest/md5'

  class MkUpdateNotFoundError < RuntimeError; end
  class MkUpdateInvalidError < RuntimeError; end

  class MkUpdate
     attr_reader :name, :version, :root_dir, :md5

    def initialize(name, metadata)
      unless metadata['root_dir']
        raise MkUpdateInvalidError, "MkUpdate #{name} does not have specify root_dir"
      end

      @name        = name
      @version     = metadata['version'].to_s || '0'
      @update_dir  = metadata['update_dir']
      @root_dir    = metadata['root_dir']
      @tar         = Razor::Util::Tar::gzip(Razor::Util::Tar::tar(@update_dir))

      #MD5 of the actual TAR.  Re Taring the same contents will actually
      #result in a different MD5 due to TAR internal metadata such as 
      #create time/date for files etc.  This is used to compare the clients
      #updates to the servers.  Re-TARing should only happen if the actual
      #contents are updated (see content_md5)
      @md5         = Digest::MD5.hexdigest(read_tar)

      #MD5 of the contents of the update, this wont change unless the
      #actual files are modified.  Changes in this MD5 are used to trigger
      #re-taring of the contents.
      @content_md5 = calc_md5
    end

    def read_tar
      @tar.rewind
      @tar.read
    end

    def refresh
      current_content_md5 = calc_md5
      unless @content_md5 == current_content_md5
        logger.info("Changes detected in update '#{@name}'.  Refreshing")
        @tar = Razor::Util::Tar::gzip(Razor::Util::Tar::tar(@update_dir))
        @md5 = Digest::MD5.hexdigest(read_tar)
        @content_md5 = current_content_md5
      end
    end

    def self.find(name)
      if yaml = find_on_mkupdate_paths("#{name}.yaml")
        metadata = YAML::load(File::read(yaml)) || {}
        if update_dir = find_on_mkupdate_paths(name)
          if File.directory?(update_dir)
            metadata['update_dir'] = update_dir
          end
        end

        unless metadata['update_dir']
          raise MkUpdateNotFoundError, "Could not find the directory for MkUpdate #{name}"
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

    def calc_md5
      files = Dir["#{@update_dir}/**/*"].reject{|f| File.directory?(f)}
      content = files.map{|f| "#{f}:#{File.read(f)}"}.join
      Digest::MD5.hexdigest(content)
    end

    def logger
      @logger ||= TorqueBox::Logger.new(self.class)
    end
  end
end
