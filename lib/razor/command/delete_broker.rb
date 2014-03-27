# -*- encoding: utf-8 -*-

class Razor::Command::DeleteBroker < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true

  def run(request, data)
    if broker = Razor::Data::Broker[:name => data['name']]
      broker.policies.count == 0 or
        request.error 400, :error => _("Broker %{name} is still used by policies") % {name: broker.name}

      broker.destroy
      action = _("broker %{name} destroyed") % {name: data['name']}
    else
      action = _("no changes; broker %{name} does not exist") % {name: data['name']}
    end
    { :result => action }
  end
end
