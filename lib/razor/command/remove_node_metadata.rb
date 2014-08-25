# -*- encoding: utf-8 -*-

# Remove a specific key or remove all (works with GET)
class Razor::Command::RemoveNodeMetadata < Razor::Command
  summary "Remove one, or all, keys from a nodes metadata"
  description <<-EOT
This is a shortcut to `modify-node-metadata` that allows for removing a single
key OR all keys in a simpler form.
  EOT

  example api: <<-EOT
Remove a single key from a node:

    {"node": "node1", "key": "my_key"}

or remove all keys from a node:

    {"node": "node1", "all": true}
  EOT

  example cli: <<-EOT
Remove a single key from a node:

    razor remove-node-metadata --node node1 --key my_key

or remove all keys from a node:

    razor remove-node-metadata --node node1 --all
  EOT


  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               help: _('The node from which to remove metadata')

  attr 'key', type: String, size: 1..Float::INFINITY,
              help: _('The name of the metadata item to remove from the node.')

  attr 'all', type: TrueClass,
              help: _('Remove all the metadata from the node.')

  require_one_of 'key', 'all'

  # Remove a specific key or remove all (works with GET)
  def run(request, data)
    node = Razor::Data::Node[:name => data['node']]
    if data['key']
      operation = { 'remove' => [ data['key'] ] }
    else
      operation = { 'clear' => true }
    end
    node.modify_metadata(operation)
  end

  def self.conform!(data)
    data.tap do |_|
      data['all'] = true if data['all'] == 'true'
    end
  end
end
