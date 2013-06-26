require 'razor/queue_classic'

# Rack middleware to establish a connection to the PostgreSQL database for
# Queue Classic, our delay job handler.  Their default model trusts the
# process environment for holding passwords, which is not optimal.
#
# This is a Rack middleware so it can be layered over our application
# transparently, establishing the correct database environment to pervasively
# enable queued messages to objects.
class Razor::Middleware::QueueClassic
  # Attach a new middleware to the Rack environment.
  def initialize(app)
    @app = app
  end

  # Handle a request, establishing the database connection for QC, and then
  # invoking the underlying application directly.  We fetch a new connection
  # from the pool each time, since we don't want to break Sequel pool
  # lifecycle rules.
  def call(env)
    Razor.database.synchronize do |connection|
      QC::Conn.connection = connection
      rval = @app.call(env)
      QC::Conn.connection = nil
      rval
    end
  end
end
