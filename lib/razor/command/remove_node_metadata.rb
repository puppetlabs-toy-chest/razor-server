# -*- encoding: utf-8 -*-

# Remove a specific key or remove all (works with GET)
class Razor::Command::RemoveNodeMetadata < Razor::Command
  attr 'node'
  attr 'key'
  attr 'value'
  attr 'all'

  def run(request, data)
    data['node'] or request.error 400,
      :error => _('must supply node')
    data['key'] or ( data['all'] and data['all'] == 'true' ) or request.error 400,
      :error => _('must supply key or set all to true')

    if node = Razor::Data::Node[:name => data['node']]
      if data['key']
        operation = { 'remove' => [ data['key'] ] }
      else
        operation = { 'clear' => true }
      end
      node.modify_metadata(operation)
    else
      request.error 400, :error => _("Node %{name} not found") % {name: data['node']}
    end
  end
end
