# -*- encoding: utf-8 -*-

# Removes a specific key or removes all (works with GET)
class Razor::Command::RemoveNodeMetadata < Razor::Command
  summary "Removes one or all keys from a node's metadata."
  description <<-EOT
This is a shortcut to `modify-node-metadata` that allows you to remove a single
key or all keys.
  EOT

  example <<-EOT
To remove a single key from a node:

    {"node": "node1", "key": "my_key"}

Or, to remove all keys from a node:

    {"node": "node1", "all": true}
  EOT


  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               help: _('The node to remove metadata from.')

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
