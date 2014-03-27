# -*- encoding: utf-8 -*-

class Razor::Command::RemovePolicyTag < Razor::Command
  attr 'name', type: String, required: true, references: Razor::Data::Policy
  attr 'tag',  type: String, required: true

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    tag = Razor::Data::Tag[:name => data['tag']]

    if tag and policy.tags.include?(tag)
      policy.remove_tag(tag)
      policy
    else
      action = _("Tag %{tag} was not on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end
end
