# -*- encoding: utf-8 -*-
class Razor::Command::CreateBroker < Razor::Command
  summary "Create a new broker configuration for hand-off of installed nodes"
  description <<-EOT
Create a new broker configuration.  Brokers are responsible for handing a node
off to a config management system, such as Puppet or Chef.  In cases where you
have no configuration management system, you can use the `noop` broker.
  EOT

  example <<-EOT
Creating a simple Puppet broker:

    {
      "name": "puppet",
      "configuration": {
         "server":      "puppet.example.org",
         "environment": "production"
      },
      "broker-type": "puppet"
    }
  EOT


  authz  '%{name}'
  attr   'name', type: String, required: true, size: 1..250
  attr   'broker-type', type: String, references: [Razor::BrokerType, :name]
  object 'configuration' do
    extra_attrs /./
  end

  def run(request, data)
    if type = data.delete("broker-type")
      data["broker_type"] = Razor::BrokerType.find(name: type) or
        request.halt [400, _("Broker type '%{name}' not found") % {name: type}]
    end

    Razor::Data::Broker.new(data).save
  end
end

