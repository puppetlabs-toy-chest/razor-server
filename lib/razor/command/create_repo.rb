# -*- encoding: utf-8 -*-
class Razor::Command::CreateRepo < Razor::Command
  summary "Creates a new repo, from an ISO image or a URL."
  description <<-EOT
Creates a new repo, which can either contain the content to install a
node, or can simply point to an existing online repo by URL.
  EOT

  example <<-EOT
Creates a repo from an ISO image, which will be downloaded and unpacked
by the Razor server in the background:

    {
      "name":    "fedora19",
      "iso-url": "http://example.com/Fedora-19-x86_64-DVD.iso"
      "task":    "fedora"
    }

You can also unpack an ISO image from a file *on the server*. Doing so does not
upload the file from the client:
    {
      "name":    "fedora19",
      "iso-url": "file:///tmp/Fedora-19-x86_64-DVD.iso"
      "task":    "fedora"
    }

Finally, you can provide a `url` property when you create the repo.
This form is only a pointer to a resource somewhere and nothing will be downloaded onto the Razor server:

    {
      "name": "fedora19",
      "url":  "http://mirrors.n-ix.net/fedora/linux/releases/19/Fedora/x86_64/os/"
      "task": "fedora"
    }
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                help: _('The name of the repo.')

  attr 'url', type: URI, exclude: 'iso-url', size: 1..1000,
              help: _('The URL of the remote repo to use.')

  attr 'iso-url', type: URI, exclude: 'url', size: 1..1000, help: _(<<-HELP)
    The URL of the ISO image to download and unpack to create the
    repo.  This can be an HTTP or HTTPS URL, or it can be a
    file URL.

    In the latter case, the file path is interpreted as a path on the
    Razor server, rather than a path on the client.  This requires that
    you manually place the ISO image on the server before invoking the
    command.
  HELP

  attr 'task', type: String, required: true, help: _(<<-HELP)
    The name of the task associated with this repo.  This is used to
    install nodes that match a policy using this repo. Generally it
    should match the OS that the URL or ISO-URL attributes point to.
  HELP

  require_one_of 'url', 'iso-url'

  def run(request, data)
    # Create a new repo.  This will implicitly, thanks to saving
    # changes, trigger the loading saga to begin.  (This takes place in the
    # same transactional context, ensuring you don't send a message to your
    # background workers without also committing this data to your database.)
    data["iso_url"] = data.delete("iso-url")
    data["task_name"] = data.delete("task")

    Razor::Data::Repo.import(data, @command).first
  end

  def self.conform!(data)
    data.tap do |_|
      data['task'] = data['task']['name'] if data['task'].is_a?(Hash) and data['task'].keys == ['name']
    end
  end
end
