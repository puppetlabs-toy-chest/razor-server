# -*- encoding: utf-8 -*-

class Razor::Command::UpdateBrokerConfiguration < Razor::Command
  summary "Update one key in a broker's configuration"
  description <<-EOT
This allows for updating, adding, and removing a single key of a broker's
configuration.
  EOT

  example api: <<-EOT
Set a single key in a broker's configuration:

    {"broker": "broker1", "key": "my_key", "value": "twelve"}
  EOT

  example cli: <<-EOT
Set a single key in a broker's configuration:

    razor update-broker-configuration --broker broker1 \\
        --key my_key --value twelve

With positional arguments, this can be shortened:

    razor update-broker-configuration broker1 my_key twelve
  EOT

  authz '%{broker}'

  attr 'broker', type: String, required: true, references: [Razor::Data::Broker, :name],
               position: 0, help: _('The broker for which to update configuration.')

  attr 'key', required: true, type: String, size: 1..Float::INFINITY,
              position: 1, help: _('The key to change in the configuration.')

  attr 'value', position: 2, help: _('The value for the configuration.')

  attr 'clear', type: TrueClass,
                     help: _(<<-EOT)
If true, the key will be either reset back to its default or
removed from the configuration, depending on whether a default exists.
EOT

  require_one_of 'value', 'clear'

  # Update/add specific configuration key
  def run(request, data)
    broker = Razor::Data::Broker[:name => data['broker']]
    config = broker.configuration
    result = if data['value']
               config[data['key']] = data['value']
               _("value for key %{name} updated") %
                   {name: data['key']}
             elsif data['clear'] and config.has_key?(data['key'])
               config.delete(data['key'])
               attr_schema = broker.broker_type.configuration_schema[data['key']]
               if attr_schema['default']
                 # The actual setting happens as part of the validation.
                 _("value for key %{name} reset to default") %
                     {name: data['key']}
               else
                 _("key %{name} removed from configuration") %
                     {name: data['key']}
               end
             else
               _("no changes; key %{name} already absent") %
                     {name: data['key']}
             end
    broker.configuration = config
    begin
      broker.save
      { :result => result }
    rescue Sequel::ValidationFailed => _
      request.error 422, :error => _("cannot clear required configuration key #{data['key']}")
    end
  end
end
