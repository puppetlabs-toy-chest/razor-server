# -*- encoding: utf-8 -*-

class Razor::Command::CancelCommand < Razor::Command
  summary "Cancel a command"
  description <<-EOT
Cancel a command to prevent later retries.

When a user issues e.g. `create-repo --iso-url http://example.com/some.iso ...`
and has a typo in that URL, there is no way for them to cancel that create-repo.
The command will continue to be re-queued, assuming the ISO is not ready yet.
This command will cause that `create-repo` command to cease being queued.
  EOT

  example <<-EOT
Cancel a command with name 123:

    {
      "name": 123
    }

  EOT

  authz '%{name}'
  attr  'name', type: Integer, required: true, references: [Razor::Data::Command, :id], help: _(<<-HELP)
    The name (or ID) of the command, as it is referenced within Razor. This will be a number.
  HELP

  def run(request, data)
    cmd = Razor::Data::Command[:id => data['name']]
    cmd.store('cancelled')
  end
end

