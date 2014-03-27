# -*- encoding: utf-8 -*-

class Razor::Command::ModifyNodeMetadata < Razor::Command
  attr 'node'
  attr 'update'
  attr 'remove'
  attr 'clear'
  attr 'no_replace'

  def run(request, data)
    data['node'] or request.error 400,
      :error => _('must supply node')
    data['update'] or data['remove'] or data['clear'] or request.error 400,
      :error => _('must supply at least one opperation')

    if data['clear'] and (data['update'] or data['remove'])
      request.error 400, :error => _('clear cannot be used with update or remove')
    end

    if data['clear']
      data['clear'] == true or data['clear'] == 'true' or request.error 400,
        :error => _("clear must be boolean true or string 'true'")
    end

    if data['no_replace']
      data['no_replace'] == true or data['no_replace'] == 'true' or request.error 400,
        :error => _("no_replace must be boolean true or string 'true'")
    end

    if data['update'] and data['remove']
      data['update'].keys.concat(data['remove']).uniq! and request.error 400,
        :error => _('cannot update and remove the same key')
    end

    if node = Razor::Data::Node[:name => data.delete('node')]
      node.modify_metadata(data)
    else
      request.error 400, :error => _("Node %{name} not found") % {name: data['node']}
    end
  end
end
