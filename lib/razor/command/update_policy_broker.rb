# -*- encoding: utf-8 -*-

class Razor::Command::UpdatePolicyBroker < Razor::Command
  summary "Update the broker associated to a policy"
  description <<-EOT
This ensures that the specified policy uses the specified broker. Note that if a
node is currently provisioning against this policy, provisioning errors may
arise.
  EOT

  example api: <<-EOT
Update policy's broker to a broker named 'other_broker':

    {"policy": "my_policy", "broker": "other_broker"}
  EOT

  example cli: <<-EOT
Update policy's broker to a broker named 'other_broker':

    razor update-policy-broker --policy my_policy --broker other_broker

With positional arguments, this can be shortened:

    razor update-policy-broker my_policy other_broker
  EOT

  authz '%{policy}'

  attr 'policy', type: String, required: true, references: [Razor::Data::Policy, :name],
                 position: 0, help: _('The policy that will have its broker updated.')

  attr 'broker', type: String, required: true, position: 1,
               references: [Razor::Data::Broker, :name],
               help: _('The broker to be used by the policy.')

  def run(_, data)
    policy = Razor::Data::Policy[:name => data['policy']]
    broker = Razor::Data::Broker[:name => data['broker']]
    broker_name = data['broker']
    if policy.broker.name != broker_name
      policy.broker = broker
      policy.save

      { :result => _("policy %{name} updated to use broker %{broker}") %
          {name: data['policy'], broker: data['broker']} }
    else
      { :result => _("no changes; policy %{name} already uses broker %{broker}") %
          {name: data['policy'], broker: data['broker']} }
    end
  end
end
