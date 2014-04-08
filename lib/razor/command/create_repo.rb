# -*- encoding: utf-8 -*-
class Razor::Command::CreateRepo < Razor::Command
  authz '%{name}'

  attr  'name',    type: String, required: true
  attr  'url',     type: URI,    exclude: 'iso-url'
  attr  'iso-url', type: URI,    exclude: 'url'
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
