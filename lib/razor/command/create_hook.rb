# -*- encoding: utf-8 -*-

class Razor::Command::CreateHook < Razor::Command
  summary "Create a new hook"
  description <<-EOT
Create a new hook, and set its initial configuration.
  EOT

  example api: <<-EOT
Create a simple hook:

    {
      "name": "myhook",
      "hook_type": "some_hook",
      "configuration": {"foo": 7, "bar": "rhubarb"}
    }
  EOT

  example cli: <<-EOT
Create a simple hook:

    razor create-hook --name myhook --hook-type some_hook \
        --configuration foo=7 --configuration bar=rhubarb
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the tag.')

  attr 'hook_type', required: true, type: String, references: [Razor::HookType, :name],
       help: _(<<-HELP)
    The hook type from which this hook is created.  The available
    hook types on your server are:
#{Razor::HookType.all.map{|n| "    - #{n}" }.join("\n")}
  HELP

  object 'configuration', alias: 'c', help: _(<<-HELP) do
    The configuration for the hook.  The acceptable values here are
    determined by the `hook_type` selected.  In general this has
    settings like a node counter or other settings which may change
    over time as the hook gets executed.

    This attribute can be abbreviated as `c` for convenience.
    HELP
    extra_attrs /./
  end

  def run(request, data)
    data["hook_type"] = Razor::HookType.find(name: data.delete("hook_type"))

    Razor::Data::Hook.import(data).first
  end
end

