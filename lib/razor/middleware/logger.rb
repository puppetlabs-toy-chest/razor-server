# -*- encoding: utf-8 -*-
# Middleware to send all web-level log messages to a TorqueBox logger
# THe Sinatra 'logger' helper will log to this, too
class Razor::Middleware::Logger
  def initialize(app)
    @app = app
    @logger = TorqueBox::Logger.new("razor.web.api")
  end

  def call(env)
    env['rack.logger'] = @logger
    env['rack.errors'] = @logger
    @app.call(env)
  end
end
