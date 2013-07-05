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

  # Deploy the queue for our internal sequel instance messaging.
  queue '/queues/razor/sequel-instance-messages' do
    processor Razor::Messaging::Sequel do
      concurrency  4
      # For the moment, no XA support in these handlers.
      xa           false
    end
  end
end
