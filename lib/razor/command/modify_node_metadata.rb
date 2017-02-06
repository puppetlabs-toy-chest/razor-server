# -*- encoding: utf-8 -*-

class Razor::Command::ModifyNodeMetadata < Razor::Command
  summary "Perform various editing operations on node metadata"
  description <<-EOT
Node metadata can be added, changed, or removed with this command; it contains
a limited editing language to make changes to the existing metadata in an
atomic fashion.

Values to keys in update operations can be structured data such as arrays and hashes.

It can also clear all metadata from a node, although that operation is
exclusive to all other editing operations, and cannot be performed atomically
with them.
  EOT

  example api: <<-EOT
Editing node metadata, by adding and removing some keys, but refusing to
modify an existing value already present on a node:

    {
        "node": "node1",
        "update": {
            "key1": "value1",
            "key2": [ "val1", "val2", "val3" ]
        }
        "remove": ["key3", "key4"],
        "no_replace": true
    }

Removing all node metadata:

    {"node": "node1", "clear": true}
  EOT

  example cli: <<-EOT
Editing node metadata, by adding and removing some keys, but refusing to
modify an existing value already present on a node:

    razor modify-node-metadata --node node1 --update key1=value1 \\
        --update key2='[ "val1", "val2", "val3" ]' --remove key3 --remove key4 --noreplace

Removing all node metadata:

    razor modify-node-metadata --node node1 --clear

With positional arguments, this can be shortened::

    razor modify-node-metadata node1 --clear
  EOT

  authz '%{node}'

  attr 'node', type: String, required: true, position: 0,
               references: [Razor::Data::Node, :name],
               help: _('The name of the node for which to modify metadata.')

  attr 'update',     type: Hash, help: _('The metadata to update')
  attr 'remove',     type: Array, help: _('The metadata to remove')
  attr 'clear',      type: :bool, exclude: ['update', 'remove'], help: _(<<-HELP)
    Remove all metadata from the node.  Cannot be used together with
    either 'update' or 'remove'.
  HELP

  attr 'no_replace', type: :bool, help: _(<<-HELP)
    If true, the `update` operation will cause this command to fail if the
    metadata key is already present on the node. No effect on `remove` or
    clear. This error can be suppressed through the `force` flag.
  HELP

  attr 'force', type: :bool, help: _(<<-HELP)
    If true, no error will be thrown when `no_replace` is true but a key
    already exists. Instead, this key will just be skipped.
  HELP

  # Take a bulk operation via POST'ed JSON
  def run(request, data)
    data['update'] or data['remove'] or data['clear'] or
      request.error 422, :error => _("at least one operation (update, remove, clear) required")

    if data['update'] and data['remove']
      data['update'].keys.concat(data['remove']).uniq! and
        request.error 422, :error => _('cannot update and remove the same key')
    end

    node = Razor::Data::Node[:name => data.delete('node')]
    begin
      node.modify_metadata(data)
    rescue Razor::Data::NoReplaceMetadataError
      request.error 409, :error => _('no_replace supplied and key is present')
    end
  end

  def self.conform!(data)
    data.tap do |_|
      data['clear'] = true if data['clear'] == 'true'
      data['clear'] = false if data['clear'] == 'false'
      data['no_replace'] = true if data['no_replace'] == 'true'
      data['no_replace'] = false if data['no_replace'] == 'false'
    end
  end
end
