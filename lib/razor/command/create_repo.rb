# -*- encoding: utf-8 -*-
class Razor::Command::CreateRepo < Razor::Command
  summary "Create a new repository, from an ISO image or a URL"
  description <<-EOT
Create a new repository, which can either contain the content to install a
node, or simply point to an existing online repository by URL.
  EOT

  example <<-EOT
Create a repository from an ISO image, which will be downloaded and unpacked
by the razor-server in the background:

    {
      "name":    "fedora19",
      "iso-url": "http://example.com/Fedora-19-x86_64-DVD.iso"
    }

You can also unpack an ISO image from a file *on the server*; this does not
upload the file from the client:
    {
      "name":    "fedora19",
      "iso-url": "file:///tmp/Fedora-19-x86_64-DVD.iso"
    }

Finally, you can providing a `url` property when you create the repository;
this form is merely a pointer to a resource somehwere and nothing will be
downloaded onto the Razor server:

    {
      "name": "fedora19",
      "url":  "http://mirrors.n-ix.net/fedora/linux/releases/19/Fedora/x86_64/os/"
    }
  EOT

  authz '%{name}'
  attr  'name',    type: String, required: true, size: 1..250
  attr  'url',     type: URI,    exclude: 'iso-url', size: 1..1000
  attr  'iso-url', type: URI,    exclude: 'url', size: 1..1000

  object 'task', required: true do
    attr 'name', type: String, required: true
  end

  require_one_of 'url', 'iso-url'

  def run(request, data)
    # Create our shiny new repo.  This will implicitly, thanks to saving
    # changes, trigger our loading saga to begin.  (Which takes place in the
    # same transactional context, ensuring we don't send a message to our
    # background workers without also committing this data to our database.)
    data["iso_url"] = data.delete("iso-url")
    if data["task"]
      data["task_name"] = data.delete("task")["name"]
    end

    repo = Razor::Data::Repo.import(@command, data).save.freeze

    # Finally, return the state (started, not complete) and the URL for the
    # final repo to our poor caller, so they can watch progress happen.
    repo
  end
end
