# -*- encoding: utf-8 -*-
class Razor::Command::CreateBroker < Razor::Command
  authz  '%{name}'
  attr   'name', type: String, required: true
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

