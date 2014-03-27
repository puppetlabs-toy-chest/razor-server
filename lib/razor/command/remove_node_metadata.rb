# -*- encoding: utf-8 -*-

# Remove a specific key or remove all (works with GET)
class Razor::Command::RemoveNodeMetadata < Razor::Command
  attr 'node', type: String, required: true, references: [Razor::Data::Node, :name]
  attr 'key',  type: String
  attr 'all',  type: [String, :bool]

  require_one_of 'key', 'all'

  # Remove a specific key or remove all (works with GET)
  def run(request, data)
    (data['all'] and data['all'] == 'true') or
      request.error 422, :error => _("invalid value for attribute 'all'")

    node = Razor::Data::Node[:name => data['node']]
    if data['key']
      operation = { 'remove' => [ data['key'] ] }
    else
      operation = { 'clear' => true }
    end
    node.modify_metadata(operation)
  end
end
