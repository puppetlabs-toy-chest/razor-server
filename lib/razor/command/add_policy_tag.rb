# -*- encoding: utf-8 -*-
class Razor::Command::AddPolicyTag < Razor::Command
  summary "Add a tag to an existing policy"
  description <<-EOT
Add a tag to an existing policy.  You can either specify an existing tag by
name, or you can create a new one by supplying the rule as well as the name.

In the later case the tag is atomically created, before adding it to the
policy.  If one fails, neither will take effect.
  EOT

  example <<-EOT
Adding the existing tag `virtual` to the policy `example`:

    {"name": "example", "tag": "virtual"}

Adding a new tag `virtual` to the policy `example`:

    {"name": "example", "tag": "virtual",
     "rule": ["=" ["fact" "virtual" "false"] "true"]}
  EOT

  authz '%{name}:%{tag}'

  attr 'name', type: String, required: true, references: Razor::Data::Policy,
               help: _('The name of the policy to add the tag to.')

  attr 'tag',  type: String, required: true, size: 1..Float::INFINITY,
               help: _('The name of the tag to be added to the policy.')

  attr 'rule', type: Array, help: _(<<-HELP)
    The `rule` is optional.  If you supply this, you are creating a new tag
    rather than adding an existing tag to the policy.  In that case this
    contains the tag rule.

    Creating a tag while adding it to the policy is atomic: if it fails for
    any reason, the policy will not be modified, and the tag will not be
    created.  You cannot end up with one change without the other.
  HELP

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
