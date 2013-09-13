require 'open3'

module Razor::ISO
  # Return the best available unpacker for ISO images, which has an `unpack`
  # method taking the ISO image path, and a destination directory.
  #
  # @raises if there is no available unpacker
  def self.unpack(iso, destination)
    unless system(find_bsdtar, 'xf', iso.to_s, '-C', destination.to_s)
      # @todo danielp 2013-07-16: ignore warnings during unpacking; is that
      # the right call?  For now, I think so, since they are 'non-fatal'
      # warnings and to date I have never hit one that was a problem for me.
      $?.exitstatus > 1 and raise "failed executing bsdtar: #{$?.inspect}"
    end
    return true
  end

  def self.find_bsdtar
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exe = File.join(path, 'bsdtar')
      return exe if File.executable? exe
    end
    raise "the bsdtar unpacker was not found in the path"
  end
end
