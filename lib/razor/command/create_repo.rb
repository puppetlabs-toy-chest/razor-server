# -*- encoding: utf-8 -*-
class Razor::Command::CreateRepo < Razor::Command
  summary "Create a new repository, from an ISO image or a URL"
  description <<-EOT
Create a new repository, which can either contain the content to install a
node, or simply point to an existing online repository by URL.
  EOT

  example api: <<-EOT
Create a repository from an ISO image, which will be downloaded and unpacked
by the razor-server in the background:

    {
      "name":    "fedora21",
      "iso_url": "http://example.com/Fedora-21-x86_64-DVD.iso"
      "task":    "fedora"
    }

You can also unpack an ISO image from a file *on the server*; this does not
upload the file from the client:
    {
      "name":    "fedora21",
      "iso_url": "file:///tmp/Fedora-21-x86_64-DVD.iso"
      "task":    "fedora"
    }

Finally, you can provide a `url` property when you create the repository;
this form is merely a pointer to a resource somewhere and nothing will be
downloaded onto the Razor server:

    {
      "name": "fedora21",
      "url":  "http://mirrors.n-ix.net/fedora/linux/releases/21/Server/x86_64/os"
      "task": "fedora"
    }
  EOT

  example cli: <<-EOT
Create a repository from an ISO image, which will be downloaded and unpacked
by the razor-server in the background:

    razor create-repo --name fedora21 \\
        --iso-url http://example.com/Fedora-21-x86_64-DVD.iso \\
        --task fedora

You can also unpack an ISO image from a file *on the server*; this does not
upload the file from the client:

    razor create-repo --name fedora21 \\
        --iso-url file:///tmp/Fedora-21-x86_64-DVD.iso \\
        --task fedora

Finally, you can provide a `url` property when you create the repository;
this form is merely a pointer to a resource somewhere and nothing will be
downloaded onto the Razor server:

    razor create-repo --name fedora21 --url \\
        http://mirrors.n-ix.net/fedora/linux/releases/21/Server/x86_64/os/ \\
        --task fedora
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..250,
                help: _('The name of the repository.')

  attr 'url', type: URI, exclude: ['iso_url', 'no_content'], size: 1..1000,
              help: _('The URL of the remote repository to use.')

  attr 'iso_url', type: URI, exclude: ['url', 'no_content'], size: 1..1000, help: _(<<-HELP)
    The URL of the ISO image to download and unpack to create the
    repository.  This can be an HTTP or HTTPS URL, or it can be a
    file URL.

    In the latter case, the file path is interpreted as a path on the
    Razor server, rather than a path on the client.  This requires that
    you manually place the ISO image on the server before invoking the
    command.
  HELP

  attr 'no_content', type: TrueClass, exclude: ['iso_url', 'url'], help: _(<<-HELP)
    For cases where extraction will be done manually, this argument
    creates a stub directory in the repo store where the extracted
    contents can be placed.
  HELP

  attr 'task', type: String, required: true, help: _(<<-HELP)
    The name of the default task associated with this repository.  This is
    used to install nodes that match a policy using this repository;
    generally it should match the OS that the URL or ISO_URL attributes point
    to. Note that this attribute can be overridden by the task on the policy.
  HELP

  require_one_of 'url', 'iso_url', 'no_content'

  def run(request, data)
    # Create our shiny new repo.  This will implicitly, thanks to saving
    # changes, trigger our loading saga to begin.  (Which takes place in the
    # same transactional context, ensuring we don't send a message to our
    # background workers without also committing this data to our database.)
    data["task_name"] = data.delete("task")

    # Remove this; it just helped bypass `url` and `iso_url`.
    data.delete('no_content')

    Razor::Data::Repo.import(data, @command).first
  end

  def self.conform!(data)
    data.tap do |_|
      data['task'] = data['task']['name'] if data['task'].is_a?(Hash) and data['task'].keys == ['name']
    end
  end
end
