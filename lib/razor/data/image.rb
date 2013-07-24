require 'tmpdir'
require 'open-uri'
require 'uri'
require 'fcntl'

# Manage our unpacked OS images on disk.  This is a relatively stateful class,
# because it is a proxy for data physically stored outside our database.
#
# That means a great deal of the code is handling the complexity of keeping
# the two in sync, as well as handling several long running tasks such as
# image downloading.
#
# @todo danielp 2013-07-10: at the moment I pretend that the image URL will
# never change.  That simplifies the initial implementation, but isn't really
# viable in the longer term.  The main complexity comes from handling that
# *after* we have downloaded and unpacked the image, which we might avoid by
# refusing to update the column at that point...
module Razor::Data
  class Image < Sequel::Model
    # The only columns that may be set through "mass assignment", which is
    # typically through the constructor.  Only enforced at the Ruby layer, but
    # since we direct everything through the model that is acceptable.
    set_allowed_columns :name, :image_url

    # When a new instance is saved, we need to make the image accessible as a
    # local file.
    def after_create
      super
      publish 'make_the_image_accessible'
    end

    # When we are destroyed, if we have a scratch directory, we need to
    # remove it.
    def after_destroy
      super

      # Try our best to remove the directory.  If it fails there is little
      # else that we could do to resolve the situation -- we already tried to
      # delete it once...
      self.tmpdir and FileUtils.remove_entry_secure(self.tmpdir, true)
    end


    # Make the image accessible on the local system, and then generate
    # a notification.  In the event the image is remote, it will be downloaded
    # and the temporary file stored for later cleanup.
    #
    # @warning this should not be called inside a transaction.
    def make_the_image_accessible
      url = URI.parse(image_url)
      if url.scheme.downcase == 'file'
        File.readable?(url.path) or raise "unable to read local file #{url.path}"
        publish 'unpack_image', url.path
      else
        publish 'unpack_image', download_file_to_tempdir(url)
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
      tmpdir   = Pathname(Dir.mktmpdir("razor-image-#{filesystem_safe_name}-download"))
      filename = tmpdir + Pathname(url.path).basename

      File.open(filename, CreateFileForWrite, 0600) do |dest|
        url.open do |source|
          # JRuby 1.7.4 requires String or IO class be passed to
          # `IO.copy_stream`, which unfortunately precludes our using it.
          # open-uri sanely returns StringIO for short bodies, which just
          # don't work here.  We should replace it with the cleaner
          # one-function version when we can.
          #
          # Preallocating the buffer reduces object churn.
          buffer = ''
          while source.read(BufferSize, buffer)
            written = dest.write(buffer)
            unless written == buffer.size
              raise "download_file_to_tempdir(#{url}): unable to cope with partial write of #{written} bytes when #{buffer.size} expected"
            end
          end

          # Try and get our data out to disk safely before we consider the
          # write completed.  That way a crash won't leak partial state, given
          # our database does try and be this conservative too.
          begin
            dest.flush
            dest.respond_to?('fdatasync') ? dest.fdatasync : dest.fsync
          rescue NotImplementedError
            # This signals that neither fdatasync nor fsync could be used on
            # this IO, which we can politely ignore, because what the heck can
            # we do anyhow?
          end
        end
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

    # Return the path on disk for our image store root; each image is unpacked
    # into a directory immediately below this root.
    def image_store_root
      # @todo danielp 2013-07-24: this should be lifted into some more global
      # validation of our configuration file.  When we figure that out, we
      # should pull it up to there.
      root = Razor.config['image_store_root'] or
        raise "`image_store_root` is not set in the configuration file"
      root = Pathname(root)
      root.absolute? or raise "`image_store_root` was not an absolute path"
      root
    end

    # Return the name of the image, made file-system safe by URL-encoding it
    # as a single string.
    def filesystem_safe_name
      URI.escape(name, '/\\?*:|"<>$\'')
      # For Windows, we should also eliminate reserved DOS device files (eg:
      # COM1) that can cause a nasty DOS by, eg, locking up forever if there
      # is nothing attached to the appropriate communication port.
    end

    # Take a local ISO image file, possible temporary, possibly permanent,
    # that we can read, and unpack it into our working directory.  Once we are
    # done, notify ourselves of that so any cleanup required can be performed.
    def unpack_image(path)
      destination = image_store_root + filesystem_safe_name
      destination.mkpath        # in case it didn't already exist
      Razor::ISO.unpack(path, destination)
      self.publish('release_temporary_image')
    end

    # Release any temporary image previously downloaded.
    def release_temporary_image
      if self.tmpdir
        FileUtils.remove_entry_secure(self.tmpdir)
        self.tmpdir = nil
        self.save
      end
    end
  end
end
