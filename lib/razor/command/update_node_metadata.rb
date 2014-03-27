# -*- encoding: utf-8 -*-

class Razor::Command::UpdateNodeMetadata < Razor::Command
  attr 'node',       type: String, required: true, references: [Razor::Data::Node, :name]
  attr 'key',        type: String, exclude: 'all'
  attr 'all',        type: [String, :bool], exclude: 'key'
  attr 'value',      required: true
  attr 'no_replace', type: [String, :bool]

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
