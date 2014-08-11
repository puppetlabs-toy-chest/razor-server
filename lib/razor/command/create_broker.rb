# -*- encoding: utf-8 -*-
class Razor::Command::CreateBroker < Razor::Command
  summary "Creates a new broker configuration for handing off installed nodes."
  description <<-EOT
Creates a new broker configuration.  Brokers are responsible for handing a node
off to a configuration management system.  In cases where you
have no configuration management system, you can use the `noop` broker.
  EOT

  example <<-EOT
To create a simple Puppet broker:

    {
      "name": "puppet",
      "configuration": {
         "server":      "puppet.example.org",
         "environment": "production"
      },
      "broker-type": "puppet"
    }
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                 help: _(<<-HELP)
    The name of the broker, as it will be referenced within Razor.
    This is the name that you supply to, for example, `create-policy` to specify
    which broker will be used to hand off the node after installation.
  HELP

  attr 'broker-type', required: true, type: String, references: [Razor::BrokerType, :name],
                      help: _(<<-HELP)
    The broker type from which this broker is created.  The available
    broker types on your server are:
#{Razor::BrokerType.all.map{|n| "    - #{n}" }.join("\n")}
  HELP

  object 'configuration', help: _(<<-HELP) do
    The configuration for the broker.  The acceptable values here are
    determined by the `broker-type` selected.  In general, this has
    settings for which server to contact and other configuration
    related to handing on the newly installed system to the final
    configuration management system.

    This attribute can be abbreviated as `c` for convenience.
  HELP
    extra_attrs /./
  end

  def run(request, data)
    type = data.delete("broker-type")
    data["broker_type"] = Razor::BrokerType.find(name: type)

    Razor::Data::Broker.import(data).first
  end

  def self.conform!(data)
    data.tap do |_|
      # Allow "c" as a shorthand.
      add_hash_alias(data, 'configuration', 'c')
    end
  end
end

