# Integration between Razor and queue_classic, in the form of monkey patching
# code to work around upstream issues.  This is shared between the core and
# the migration code, so be very, very careful about what you depend on here.

require 'queue_classic'

# Unfortunately, we need to work around a QC issue: they test for exact class
# equality on PG::Connection in their connection assignment handler, and
# Sequel gives us a subclass of the same.  This monkey-patch works around that
# issue until upstream fixes the issue:
#
# https://github.com/ryandotsmith/queue_classic/issues/161
module QC::Conn
  # This is lifted *directly* from the original!
  def connection=(connection)
    # This is the one change: `s/instance_of/kind_of/` on the next line, and
    # permit `nil` values to remove the connection -- since we don't want to
    # hold it past the end of the pool lease.
    unless connection.kind_of? PG::Connection or connection.nil?
      c = connection.class
      err = "connection must be an instance of PG::Connection, but was #{c}"
      raise(ArgumentError, err)
    end
    @connection = connection
  end
end
