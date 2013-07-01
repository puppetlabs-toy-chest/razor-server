# Configure TorqueBox global settings for our application.
#
# You can override this with your deployment descriptor outside this
# application; these establish our default, supported, configuration.
TorqueBox.configure do
  ruby do
    version       '1.9'
    compile_mode  'jit'
    interactive   false
  end

  web do
    context  '/'
    rackup   'config.ru'
  end
end
