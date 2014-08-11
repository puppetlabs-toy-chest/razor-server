# -*- encoding: utf-8 -*-

class Razor::Command::UpdateNodeMetadata < Razor::Command
  summary "Updates one key in a node's metadata."
  description <<-EOT
This is a shortcut to `modify-node-metadata` that allows for updating or
adding or removing a single key, in a simpler form than the full
editing language.
  EOT

  example <<-EOT
To set a single key from a node:

    {"node": "node1", "key": "my_key", "value": "twelve"}
  EOT

  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               help: _('The node to update metadata on.')

  attr 'key', type: String, exclude: 'all', size: 1..Float::INFINITY,
              help: _('The key to change in the metadata.')

  attr 'value', required: true,
                help: _('The value for the metadata.')

  attr 'no_replace', type: [String, :bool],
                     help: _('If true, it is an error to try and change an existing key.')

  attr 'all', type: [String, :bool], exclude: 'key',
              help: _('The update applies to all keys.')

  require_one_of 'key', 'all'

  # Update/add specific metadata key (works with GET)
  def run(request, data)
    node = Razor::Data::Node[:name => data['node']]
    operation = { 'update' => { data['key'] => data['value'] } }
    operation['no_replace'] = data['no-replace']

    node.modify_metadata(operation)
  end
  
  def self.conform!(data)
    data.tap do |_|
      data['no-replace'] = data.delete('no_replace') if data.has_key?('no_replace')
      data['all'] = true if data['all'] == 'true'
      data['all'] = false if data['all'] == 'false'
      data['no-replace'] = true if data['no-replace'] == 'true'
      data['no-replace'] = false if data['no-replace'] == 'false'
    end
  end
end
