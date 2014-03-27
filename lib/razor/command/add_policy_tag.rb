# -*- encoding: utf-8 -*-
class Razor::Command::AddPolicyTag < Razor::Command
  attr 'name'
  attr 'rule'
  attr 'tag'

  def run(request, data)
    data['name'] or request.error 400, :error => _("Supply policy name to which the tag is to be added")
    data['tag'] or request.error 400, :error => _("Supply the name of the tag you which to add")

    policy = Razor::Data::Policy[:name => data['name']] or request.error 404, :error => _("Policy %{name} does not exist") % {name: name}
    tag = Razor::Data::Tag.find_or_create_with_rule(
      { 'name' => data['tag'], 'rule' => data['rule'] }
    ) or request.error 404, :error => _("Tag %{name} does not exist and no rule to create it supplied.") % {name: data['tag']}

    unless policy.tags.include?(tag)
      policy.add_tag(tag)
      policy
    else
      action = _("Tag %{tag} already on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end
end
