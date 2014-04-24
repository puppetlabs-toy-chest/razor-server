# -*- encoding: utf-8 -*-

class Razor::Command::UpdateNodeMetadata < Razor::Command
  summary "Update one key in a nodes metadata"
  description <<-EOT
This is a shortcut to `modify-node-metadata` that allows for updating or
adding removing a single key, in a simpler form that the full
editing language.
  EOT

  example <<-EOT
Set a single key from a node:

    {"node": "node1", "key": "my_key", "value": "twelve"}
  EOT

  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               help: _('The node to update metadata on')

  attr 'key', type: String, exclude: 'all', size: 1..Float::INFINITY,
              help: _('the key to change in the metadata')

  attr 'value', required: true,
                help: _('the value for the metadata')

  attr 'no_replace', type: [String, :bool],
                     help: _('If true, it is an error to try and change an existing key')

  attr 'all', type: [String, :bool], exclude: 'key',
              help: _('The update applies to all keys')

  require_one_of 'key', 'all'

  # Update/add specific metadata key (works with GET)
  def run(request, data)
    # This will get removed when coercion is no longer supported.
    (!data['no_replace'] or ['true', true].include? data['no_replace']) or
      request.error 422, :error => _("'no_replace' must be boolean true or string 'true'")
    (!data['all'] or (['true', true].include? data['all'])) or
      request.error 422, :error => _("'all' must be boolean true or string 'true'")

    node = Razor::Data::Node[:name => data['node']]
    operation = { 'update' => { data['key'] => data['value'] } }
    operation['no_replace'] = true unless operation['no_replace'].nil?

    node.modify_metadata(operation)
  end
end
