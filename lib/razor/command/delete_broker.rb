# -*- encoding: utf-8 -*-

class Razor::Command::DeleteBroker < Razor::Command
  summary "Deletes an existing broker configuration."
  description <<-EOT
Deletes a broker configuration from Razor.  If the broker is currently used by
a policy, the attempt will fail.
  EOT

  example <<-EOT
To delete the unused broker configuration "obsolete":

    {"name": "obsolete"}
  EOT


  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                help: _('The name of the broker to delete.')

  def run(request, data)
    if broker = Razor::Data::Broker[:name => data['name']]
      broker.policies.count == 0 or
        request.error 400, :error => _("Broker %{name} is still used by policies.") % {name: broker.name}

      broker.destroy
      action = _("Broker %{name} destroyed.") % {name: data['name']}
    else
      action = _("No changes; broker %{name} does not exist.") % {name: data['name']}
    end
    { :result => action }
  end
end
