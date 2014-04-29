# -*- encoding: utf-8 -*-

class Razor::Command::ModifyNodeMetadata < Razor::Command
  summary "Perform various editing operations on node metadata"
  description <<-EOT
Node metadata can be added, changed, or removed with this command; it contains
a limited editing language to make changes to the existing metadata in an
atomic fashion.

It can also clear all metadata from a node, although that operation is
exclusive to all other editing operations, and cannot be performed atomically
with them.
  EOT

  example <<-EOT
Editing node metadata, by adding and removing some keys, but refusing to
modify an existing value already present on a node:

    {
        "node": "node1",
        "update": {
            "key1": "value1",
            "key2": "value2"
        }
        "remove": ["key3", "key4"],
        "no_replace": true
    }

Removing all node metadata:

    {"node": "node1", "clear": true}
  EOT

  authz '%{node}'

  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name],
               help: _('The name of the node to modify metadata of.')

  attr 'update',     type: Hash, help: _('The metadata to update')
  attr 'remove',     type: Array, help: _('The metadata to remove')
  attr 'clear',      type: [String, :bool], exclude: ['update', 'remove'], help: _(<<-HELP)
    Remove all metadata from the node.  Cannot be used together with
    either 'update' or 'remove'.
  HELP

  attr 'no_replace', type: [String, :bool], help: _(<<-HELP)
    If true, the `update` operation will cause this command to fail if the
    metadata key is already present on the node.  No effect on `remove` or
    clear.
  HELP

  # Take a bulk operation via POST'ed JSON
  def run(request, data)
    data['update'] or data['remove'] or data['clear'] or
      request.error 422, :error => _("at least one operation (update, remove, clear) required")
    [nil, true, false, 'true', 'false'].include?(data['clear']) or
      request.error 422, :error => _("clear must be boolean true or string 'true'")
    [nil, true, false, 'true', 'false'].include?(data['no_replace']) or
      request.error 422, :error => _("no_replace must be boolean true or string 'true'")

    if data['update'] and data['remove']
      data['update'].keys.concat(data['remove']).uniq! and
        request.error 422, :error => _('cannot update and remove the same key')
    end

    node = Razor::Data::Node[:name => data.delete('node')]
    node.modify_metadata(data)
  end
end
