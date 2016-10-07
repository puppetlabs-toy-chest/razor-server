# -*- encoding: utf-8 -*-

class Razor::Command::UpdatePolicyNodeMetadata < Razor::Command
  summary "Update one key in a policy's node_metadata"
  description <<-EOT
This command can also be used to update a single key in a policy's
`node_metadata`.
  EOT

  example api: <<-EOT
Set a single key for a policy's node_metadata:

    {"policy": "policy1", "key": "my_key", "value": "twelve"}
  EOT

  example cli: <<-EOT
Set a single key for a policy's `node_metadata`:

    razor update-policy-node-metadata --policy policy1\\
        --key my_key --value twelve

With positional arguments, this can be shortened:

    razor update-policy-node-metadata policy1 my_key twelve
  EOT

  authz '%{policy}'

  attr 'policy', type: String, required: true, references: [Razor::Data::Policy, :name],
                 position: 0, help: _('The policy for which to update the associated node metadata.')

  attr 'key', required: true, type: String, size: 1..Float::INFINITY,
              position: 1, help: _('The key to change in the metadata.')

  attr 'value', required: true,
                position: 2, help: _('The value for the metadata.')

  attr 'no_replace', type: :bool,
                     help: _('If true, it is an error to try to change an existing key')

  # Update/add specific metadata key (works with GET)
  def run(request, data)
    policy = Razor::Data::Policy[:name => data['policy']]
    if data['no_replace'] && (policy.node_metadata || {}).has_key?(data['key'])
      request.error 409, { :error => _('no_replace supplied and key is present') }
    else
      policy.node_metadata = (policy.node_metadata || {}).merge({data['key'] => data['value']})
      policy.save
      policy
    end
  end

  def self.conform!(data)
    data.tap do |_|
      data['no_replace'] = true if data['no_replace'] == 'true'
      data['no_replace'] = false if data['no_replace'] == 'false'
    end
  end
end
