# -*- encoding: utf-8 -*-
require 'tmpdir'
require 'open-uri'
require 'uri'
require 'fcntl'
require 'archive'

# Manage our unpacked OS repos on disk.  This is a relatively stateful class,
# because it is a proxy for data physically stored outside our database.
#
# That means a great deal of the code is handling the complexity of keeping
# the two in sync, as well as handling several long running tasks such as
# repo downloading.
#
# @todo danielp 2013-07-10: at the moment I pretend that the repo URL will
# never change.  That simplifies the initial implementation, but isn't really
# viable in the longer term.  The main complexity comes from handling that
# *after* we have downloaded and unpacked the repo, which we might avoid by
# refusing to update the column at that point...
module Razor::Data
  class Repo < Sequel::Model
    # The only columns that may be set through "mass assignment", which is
    # typically through the constructor.  Only enforced at the Ruby layer, but
    # since we direct everything through the model that is acceptable.
    set_allowed_columns :name, :iso_url, :url, :task_name
    one_to_many :events

    # Create a new repo and kick off the background import of its ISO (if
    # there is one) The +command+ is used to track progress of the import
    # and report any errors that might happen
    def self.import(data, command)
      super.tap do |repo, new|
        new and repo.publish('make_the_repo_accessible', command)
      end
    end

    # When we are destroyed, if we have a scratch directory, we need to
    # remove it.
    def after_destroy
      super

      # Try our best to remove the directory.  If it fails there is little
      # else that we could do to resolve the situation -- we already tried to
      # delete it once...
      self.tmpdir and FileUtils.remove_entry_secure(self.tmpdir, true)

      # Remove repo directory.
      if Dir.exist?(iso_location)
        FileUtils.remove_entry_secure(iso_location, true)
      end
    end

    def validate
      super
      if url and iso_url
        errors.add(:urls, _("only one of the 'url' and 'iso_url' attributes can be set at the same time"))
      end
    end

    def task
      Razor::Task.find(task_name)
    end

    # Make the repo accessible on the local system, and then generate
    # a notification.  In the event the repo is remote, it will be downloaded
    # and the temporary file stored for later cleanup.
    #
    # @warning this should not be called inside a transaction.
    def make_the_repo_accessible(command)
      command.store('running')
      if url.nil? and iso_url.nil?
        # This is done to create a stub directory to manually install the repo.
        publish 'unpack_repo', command, nil
      else
        url = URI.parse(iso_url)
        if url.scheme.downcase == 'file'
          File.readable?(url.path) or raise _("unable to read local file %{path}") % {path: url.path}
          publish 'unpack_repo', command, url.path
        else
          publish 'unpack_repo', command, download_file_to_tempdir(url)
        end
      end
    end

    # Convenience constant for securely create-only file opening.
    CreateFileForWrite = Fcntl::O_CREAT | Fcntl::O_EXCL | Fcntl::O_WRONLY

    # The size of the internal buffer used for copying data.
    BufferSize = 32 * 1024 * 1024 # 32MB worth of power-of-two memory pages

    # Download a remote file to a newly allocated temporary directory, and
    # return the path to the file.
    #
    # the file is removed on error, but is not otherwise automatically
    # cleaned up.  this will update the current object to store the temporary
    # directories as we go, to ensure that we can later clean up
    # after ourselves.
    def download_file_to_tempdir(url)
      tmpdir   = Pathname(Dir.mktmpdir("razor-repo-#{filesystem_safe_name}-download"))
      filename = tmpdir + Pathname(url.path).basename

      result = url.open
      unless result.is_a?(File)
        # Create Tempfile to converge code flow.
        tmpfile = Tempfile.new filename.to_s
        tmpfile.binmode
        tmpfile << result.read
        result = tmpfile
      end
      begin
        # Try and get our data out to disk safely before we consider the
        # write completed.  That way a crash won't leak partial state, given
        # our database does try and be this conservative too.
        begin
          result.flush
          result.respond_to?('fdatasync') ? result.fdatasync : result.fsync
        rescue NotImplementedError
          # This signals that neither fdatasync nor fsync could be used on
          # this IO, which we can politely ignore, because what the heck can
          # we do anyhow?
        end
        FileUtils.mv(result, filename)
      ensure
        result.close
      end

      # Downloading was successful, so save our temporary directory for later
      # cleanup, and return the path of the file.
      self.tmpdir = tmpdir
      self.save

      return filename.to_s

    rescue Exception => e
      # Try our best to remove the directory, but don't let that stop the rest
      # of the recovery process from proceeding.  This might leak files on
      # disk, but in that case there is little else that we could do to
      # resolve the situation -- we already tried to delete the file/dir...
      FileUtils.remove_entry_secure(tmpdir, true)
      raise e
    end

    # Return the path on disk for our repo store root; each repo is unpacked
    # into a directory immediately below this root.
    def repo_store_root
      Pathname(Razor.config['repo_store_root'])
    end

    # Reserved words in DOS and NTFS filesystems.  Gotta love the magic.
    # This only includes words that are not going to be otherwise escaped.
    ReservedFilenames = %w{
      CON PRN AUX NUL
      COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9
      LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9
    }

    # The same thing, turned into a regexp.
    ReservedFilenameRegexp = /^(#{ReservedFilenames.join('|')})(?:$|\.)/i

    # Characters that are escaped for both DOS, Windows, Unix, etc,
    # compatibility.  Treated as a set of characters, not just a string.
    ReservedCharacters = %r{[\u0000-\u001f\u007f%/\\?*:|"<>$\',]}

    # Return the name of the repo, made file-system safe by URL-encoding it
    # as a single string.
    def filesystem_safe_name
      name.
        gsub(ReservedCharacters) {|sub| '%%%02X' % sub.ord }.
        gsub(ReservedFilenameRegexp) {|sub| sub.gsub(/[^.]/) {|c| '%%%02X' % c.ord } }
    end

    # Take a local ISO repo file, possible temporary, possibly permanent,
    # that we can read, and unpack it into our working directory.  Once we are
    # done, notify ourselves of that so any cleanup required can be performed.
    def unpack_repo(command, path)
      destination = iso_location
      destination.mkpath        # in case it didn't already exist
      Archive.extract(path, destination) if path
      self.publish('release_temporary_repo', command)
    end

    def iso_location
      repo_store_root + filesystem_safe_name
    end
    private :iso_location

    # Release any temporary repo previously downloaded.
    def release_temporary_repo(command)
      if self.tmpdir
        FileUtils.remove_entry_secure(self.tmpdir)
        self.tmpdir = nil
        self.save
      end
      command.store('finished')
    end


    def self.find_file_ignoring_case(root, path)
      TorqueBox::Logger.new.info("find_file_ignoring_case(#{root}/#{path})")

      # Do we have a file with matching case?  If so, return it.  This should
      # help address the situation if we ever have a case-sensitive installer
      # that expects different files with the same name but not the same case,
      # because we will default to the "right" one first.  Hopefully.
      clean = File.join(root, path)
      if File.exist? clean
        clean
      else
        # We split the path into segments and dispatch to our recursive worker,
        # which will return the first completely matching file, or nil.  This is
        # just a nicer way of invoking the recursive function...
        path = path.sub(%r{^/+}, '').split(%r{/+})
        _find_file_ignoring_case_recursively(root.to_s, *path)
      end
    end

    def self._find_file_ignoring_case_recursively(root, segment, *rest)
      # Find matching files in the root, if any, and retain the
      # case-insensitively matching entries from it.
      entries = Dir.entries(root).select {|x| x.downcase == segment.downcase } rescue nil
      return nil unless entries and not entries.empty?

      # Are we looking for the actual file, or another directory?
      if rest.empty?
        entries.each do |try|
          file = File.join(root, try)
          if File.exist?(file)
            TorqueBox::Logger.new.info("matched case-insensitive file #{file}")
            return file
          end
        end
      else
        # We are looking for something deeper, so map through these
        # possibilities and see if we have a match down there.
        entries.each do |try|
          found = _find_file_ignoring_case_recursively(File.join(root, try), *rest)
          return found if found
        end
      end

      return nil
    end
  end
end
