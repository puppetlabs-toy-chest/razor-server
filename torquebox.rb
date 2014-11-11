# -*- encoding: utf-8 -*-
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

  # Deploy the queue for hooks messaging, which requires sequential
  # processing.
  queue '/queues/razor/sequel-hooks-messages' do
    processor Razor::Messaging::Sequel do
      # Concurrency of 1 + singleton are crucial for the correctness
      # of hook processing order.
      singleton    true
      concurrency  1
      # For the moment, no XA support in these handlers.
      xa           false
    end
  end

  # The naming is because we want the filename to be `ipmi.rb`.
  job Razor::ScheduledJobs::Ipmi do
    description 'IPMI power state poller'
    cron        '0 */5 * * * ?'
    # Only run on one node across a cluster, if you set one up.
    singleton    true
  end
end
