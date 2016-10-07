# -*- encoding: utf-8 -*-

class Razor::Command::UpdateNodeMetadata < Razor::Command
  summary "Update one key in a node's metadata"
  description <<-EOT
This is a shortcut to `modify-node-metadata` that allows for updating or
adding a single key, in a simpler form than the full
editing language.
  EOT

  example api: <<-EOT
Set a single key from a node:

    {"node": "node1", "key": "my_key", "value": "twelve"}
  EOT

  example cli: <<-EOT
Set a single key from a node:

    razor update-node-metadata --node node1 \\
        --key my_key --value twelve

With positional arguments, this can be shortened:

    razor update-node-metadata node1 my_key twelve
  EOT

  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               position: 0, help: _('The node for which to update metadata.')

  attr 'key', required: true, type: String, size: 1..Float::INFINITY,
              position: 1, help: _('The key to change in the metadata.')

  attr 'value', required: true,
                position: 2, help: _('The value for the metadata.')

  attr 'no_replace', type: :bool,
                     help: _('If true, it is an error to try to change an existing key')

  # Update/add specific metadata key (works with GET)
  def run(request, data)
    node = Razor::Data::Node[:name => data['node']]
    operation = { 'update' => { data['key'] => data['value'] } }
    operation['no_replace'] = data['no_replace']

    begin
      node.modify_metadata(operation)
    rescue Razor::Data::NoReplaceMetadataError
      request.error 409, :error => _('no_replace supplied and key is present')
    end
  end

  def self.conform!(data)
    data.tap do |_|
      data['all'] = true if data['all'] == 'true'
      data['all'] = false if data['all'] == 'false'
      data['no_replace'] = true if data['no_replace'] == 'true'
      data['no_replace'] = false if data['no_replace'] == 'false'
    end
  end
end
