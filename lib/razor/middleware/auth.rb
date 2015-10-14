# -*- encoding: utf-8 -*-
require 'sinatra'
require 'java'

class Razor::Middleware::Auth
  def initialize(app, *patterns)
    @app      = app
    @patterns = patterns.map do |e|
      case e
      when String then %r(^#{e}($|/))i
      when Regexp then e
      else raise TypeError, _("patterns must be strings or regular expressions")
      end
    end
  end

  def logger
    @logger ||= TorqueBox::Logger.new('razor.auth')
  end

  def enabled?
    Razor.config['auth.enabled']
  end

  def protected_path?(req)
    @patterns.any? {|p| p === req.path_info }
  end

  def authenticated?(subject)
    subject.authenticated? or subject.remembered?
  end

  def local?(req)
    req.ip == '127.0.0.1' and Razor.config['auth.allow_localhost']
  end

  def call(env)
    # Try authentication, regardless of security being enabled or disabled.
    req = Rack::Request.new(env)
    subject = authenticate(req)

    # @todo danielp 2013-12-17: at the moment we trust either authenticated
    # or remembered credentials, even though we don't support the later.
    if enabled? and protected_path?(req) and not authenticated?(subject) and not local?(req)
      # Auth was required, but we were neither authenticated or remembered.
      [401, {'WWW-Authenticate' => 'Basic realm="Razor"'}, ["Access Denied\n"]]
    else
      # Bind our subject to the thread context.
      state = org.apache.shiro.subject.support.SubjectThreadState.new(subject)
      begin
        state.bind
        @app.call(env)
      ensure
        state.restore
      end
    end
  end

  def authenticate(req)
    # Set up our subject context; this is very ... thin, since we know so
    # little about the user in the current context.  Once we do persistent
    # session tokens or whatever this will change.
    context = org.apache.shiro.subject.support.DefaultSubjectContext.new
    context.host = req.ip

    # Turn the subject context into a subject instance.
    subject = Razor.security_manager.create_subject(context)

    auth = Rack::Auth::Basic::Request.new(req.env)
    if auth.provided? and auth.basic? and auth.credentials
      begin
        # args are <username>, <password>
        token = org.apache.shiro.authc.UsernamePasswordToken.new(*auth.credentials)
        # @todo danielp 2013-12-17: verify this works correctly in the case
        # of forwarding proxies, x-forwarded-for, and clients that fake
        # x-forwarded-for headers.  Otherwise just ditch it.
        token.host = req.ip

        # This will raise an exception on auth failure, but I actually
        # want to swallow that and rely on the fact that they will still
        # not be authenticated later.
        begin
          subject.login(token)
        rescue => e
          logger.warn("API auth login failed: #{e}")
        end
      ensure
        # This is recommended practice from Shiro, which triggers their
        # overwrite of internal storage for the password string.  Sadly,
        # we can't quite match their security efforts, but better not to
        # entirely defeat them.
        token and token.clear
      end
    end

    # ...and return our subject to the caller.
    subject
  end
end
