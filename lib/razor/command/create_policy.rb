# -*- encoding: utf-8 -*-

class Razor::Command::CreatePolicy < Razor::Command
  summary "Create a new policy"
  description <<-EOT
Policies tie together the rules, as tags, with the task and repo containing
the OS to install, and the broker for post-install configuration.

The overall list of policies is ordered, and policies are considered in that
order. When a new policy is created, the entry `before` or `after` can be
used to put the new policy into the table before or after another
policy. If neither `before` or `after` are specified, the policy is
appended to the policy table.
  EOT

  example <<-EOT
A sample policy installing CentOS 6.4:

    {
      "name":          "centos-for-small",
      "repo":          "centos-6.4",
      "task":          "centos",
      "broker":        "noop",
      "enabled":       true,
      "hostname":      "host${id}.example.com",
      "root-password": "secret",
      "max-count":     20,
      "before":        "other policy",
      "tags": [
        {"name": "small", "rule": ["<=", ["num", ["fact", "processorcount"]], 2]}
      ]
    }
  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the policy to create.')

  attr 'hostname', type: String, required: true, size: 1..Float::INFINITY, help: _(<<-HELP)
    The hostname pattern to use for newly installed nodes.  This is filled
    in on a per-node basis, and then supplied to the task to be configured
    appropriately on the newly installed node.

    Substitutions are performed using `${...}` syntax, and the available
    substitution names on your server are:

    - id -- the internal node ID number
  HELP

  attr 'root-password', required: true, type: String, size: 1..Float::INFINITY, help: _(<<-HELP)
    The root password for newly installed systems.  This is passed directly
    to the individual task, rather than "understood" by the server, so the
    valid values are dependent on the individual task capabilities.
  HELP

  attr 'enabled', type: :bool, help: _('Is this policy enabled when first created?')

  attr 'max-count', type: Integer, help: _(<<-HELP)
    The maximum number of nodes that can bind to this policy.
    If omitted, the policy is 'unlimited', and no maximum is applied.
  HELP

  object 'before', exclude: 'after', help: _(<<-HELP) do
    The policy to create this policy before in the policy list.
  HELP
    attr 'name', type: String, required: true, references: Razor::Data::Policy,
                 help: _('The name of the policy to create this policy before.')
  end

  object 'after', exclude: 'before', help: _(<<-HELP) do
    The policy to create this policy after in the policy list.
  HELP
    attr 'name', type: String, required: true, references: Razor::Data::Policy,
                 help: _('The name of the policy to create this policy after.')
  end

  array 'tags', help: _(<<-HELP) do
    The array of tags that are used for matching nodes to this policy.

    When a node has all these tags matched on it, it will be a candidate
    for binding to this policy.
  HELP
    object do
      attr 'name', type: String, required: true, help: _('The name of the tag.')
      array 'rule', help: _(<<-HELP)
        The `rule` is optional.  If you supply this, you are creating a new tag
        rather than adding an existing tag to the policy.  In that case this
        contains the tag rule.

        Creating a tag while adding it to the policy is atomic: if it fails for
        any reason, the policy will not be modified, and the tag will not be
        created.  You cannot end up with one change without the other.
      HELP
    end
  end

  object 'repo', help: _(<<-HELP) do
    The repository containing the OS to be installed by this policy.  This
    should match the task assigned, or bad things will happen.
  HELP
    attr 'name', type: String, required: true, references: Razor::Data::Repo,
                 help: _('The name of the repository to use.')
  end

  object 'broker', help: _(<<-HELP) do
    The broker to use when the node is fully installed, and is ready to hand
    off to the final configuration management system.  If you have no ongoing
    configuration management, the supplied `noop` broker will do nothing.

    Please note that this is a broker created with the `create-broker` command,
    which is distinct from the broker types found on disk.
  HELP
    attr 'name', type: String, required: true, references: Razor::Data::Broker,
                 help: _('The name of the broker to use.')
  end

  object 'task', help: _(<<-HELP) do
    The task used to install nodes that match this policy.  This must match
    the selected repo, as it references files contained within that repository.
  HELP
    attr 'name', type: String, required: true,
                 help: _('The name of the task to apply.')
  end

  def run(request, data)
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find_or_create_with_rule(t)
    end.uniq

    data["repo"]   &&= Razor::Data::Repo[:name => data["repo"]["name"]]
    data["broker"] &&= Razor::Data::Broker[:name => data["broker"]["name"]]

    if data["task"]
      data["task_name"] = data.delete("task")["name"]
    end

    data["hostname_pattern"] = data.delete("hostname")

    # Handle positioning in the policy table
    if data["before"] or data["after"]
      position = data["before"] ? "before" : "after"
      neighbor = Razor::Data::Policy[:name => data.delete(position)["name"]]
    end

    data["enabled"] = true if data["enabled"].nil?

    data["max_count"] = data.delete("max-count") if data["max-count"]
    data["root_password"] = data.delete("root-password") if data["root-password"]
    # Create the policy
    policy = Razor::Data::Policy.new(data).save
    tags.each { |t| policy.add_tag(t) }
    position and policy.move(position, neighbor)
    policy.save

    return policy
  end

  def self.conform!(data)
    data.tap do |_|
      data['before'] = { 'name' => data['before'] } if data['before'].is_a?(String)
      data['after'] = { 'name' => data['after'] } if data['after'].is_a?(String)
      data['tags'] = data['tags'].map { |item| item.is_a?(String) ? { 'name' => item } : item } if data['tags'].is_a?(Array)
      data['repo'] = { 'name' => data['repo'] } if data['repo'].is_a?(String)
      data['broker'] = { 'name' => data['broker'] } if data['broker'].is_a?(String)
      data['task'] = { 'name' => data['task'] } if data['task'].is_a?(String)
      data['root-password'] = data.delete('root_password') if data['root_password']
      data['max-count'] = data.delete('max_count') if data['max_count']
    end
  end
end
