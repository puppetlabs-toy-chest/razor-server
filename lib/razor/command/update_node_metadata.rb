# -*- encoding: utf-8 -*-

class Razor::Command::UpdateNodeMetadata < Razor::Command
  attr 'node'
  attr 'key'
  attr 'value'
  attr 'no_replace'

  def run(request, data)
    data['node'] or request.error 400,
      :error => _('must supply node')
    data['key'] or ( data['all'] and data['all'] == 'true' ) or request.error 400,
      :error => _('must supply key or set all to true')
    data['value'] or request.error 400,
      :error => _('must supply value')

    if data['no_replace']
      data['no_replace'] == true or data['no_replace'] == 'true' or request.error 400,
        :error => _("no_replace must be boolean true or string 'true'")
    end

    if node = Razor::Data::Node[:name => data['node']]
      operation = { 'update' => { data['key'] => data['value'] } }
      operation['no_replace'] = true unless operation['no_replace'].nil?

      node.modify_metadata(operation)
    else
      request.error 400, :error => "Node #{data['node']} not found"
    end
  end
end
