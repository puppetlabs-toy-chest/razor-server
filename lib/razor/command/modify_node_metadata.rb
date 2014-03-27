# -*- encoding: utf-8 -*-

class Razor::Command::ModifyNodeMetadata < Razor::Command
  attr 'node',       type: String, required: true, references: [Razor::Data::Node, :name]
  attr 'update',     type: Hash
  attr 'remove',     type: Array
  attr 'clear',      type: [String, :bool], exclude: ['update', 'remove']
  attr 'no_replace', type: [String, :bool]

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
