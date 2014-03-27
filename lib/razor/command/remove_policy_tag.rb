# -*- encoding: utf-8 -*-

class Razor::Command::RemovePolicyTag < Razor::Command
  attr 'name'
  attr 'tag'

  def run(request, data)
    data['name'] or request.error 400,
    :error => _("Supply policy name to which the tag is to be removed")
    data['tag'] or request.error 400,
    :error => _("Supply the name of the tag you which to remove")

    policy = Razor::Data::Policy[:name => data['name']] or request.error 404,
    :error => _("Policy %{name} does not exist") % {name: data['name']}
    tag = Razor::Data::Tag[:name => data['tag']]

    if tag
      if policy.tags.include?(tag)
        policy.remove_tag(tag)
        policy
      else
        action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
        { :result => action }
      end
    else
      action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end
end
