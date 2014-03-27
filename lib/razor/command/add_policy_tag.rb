# -*- encoding: utf-8 -*-
class Razor::Command::AddPolicyTag < Razor::Command
  attr 'name', type: String, required: true, references: Razor::Data::Policy
  attr 'tag',  type: String, required: true
  attr 'rule', type: Array

  def run(request, data)
    policy = Razor::Data::Policy[:name => data['name']]
    begin
      tag = Razor::Data::Tag.
        find_or_create_with_rule('name' => data['tag'], 'rule' => data['rule'])
    rescue ArgumentError => e
      request.error 422, e.message
    end

    unless policy.tags.include?(tag)
      policy.add_tag(tag)
      policy
    else
      action = _("Tag %{tag} already on policy %{policy}") % {tag: data['tag'], policy: data['name']}
      { :result => action }
    end
  end
end
