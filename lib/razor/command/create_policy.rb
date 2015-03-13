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

  example api: <<-EOT
A sample policy installing CentOS 6.4:

    {
      "name":          "centos-for-small",
      "repo":          "centos-6.4",
      "task":          "centos",
      "broker":        "noop",
      "enabled":       true,
      "hostname":      "host${id}.example.com",
      "root_password": "secret",
      "max_count":     20,
      "before":        "other policy",
      "tags":          ["small"],
      "node_metadata": {"key": "value"}
    }
  EOT

  example cli: <<-EOT
A sample policy installing CentOS 6.4:

    razor create-policy --name centos-for-small \\
      --repo centos-6.4 --task centos --broker noop \\
      --enabled --hostname "host${id}.example.com" \\
      --root-password secret --max-count 20 \\
      --before "other policy" --tag small --node-metadata key=value
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

  attr 'root_password', required: true, type: String, size: 1..Float::INFINITY, help: _(<<-HELP)
    The root password for newly installed systems.  This is passed directly
    to the individual task, rather than "understood" by the server, so the
    valid values are dependent on the individual task capabilities.
  HELP

  attr 'enabled', type: :bool, help: _('Is this policy enabled when first created?')

  attr 'max_count', type: Integer, help: _(<<-HELP)
    The maximum number of nodes that can bind to this policy.
    If omitted, the policy is 'unlimited', and no maximum is applied.
  HELP

  attr 'before', type: String, references: Razor::Data::Policy, exclude: 'after', help: _(<<-HELP)
    The name of the policy to create this policy before in the policy list.
  HELP

  attr 'after', type: String, exclude: 'before', references: Razor::Data::Policy, help: _(<<-HELP)
    The name of the policy to create this policy after in the policy list.
  HELP

  array 'tags', alias: 'tag', help: _(<<-HELP) do
    The names of tags that are used for matching nodes to this policy.

    When a node has all these tags matched on it, it will be a candidate
    for binding to this policy.
  HELP
    element type: String, references: Razor::Data::Tag
  end

  attr 'repo', type: String, required: true, references: Razor::Data::Repo, help: _(<<-HELP)
    The name of the repository containing the OS to be installed by this policy.
    This should match the task assigned, or bad things will happen.
  HELP

  attr 'broker', type: String, required: true, references: Razor::Data::Broker, help: _(<<-HELP)
    The name of the broker to use when the node is fully installed, and is ready
    to hand off to the final configuration management system.  If you have no
    ongoing configuration management, the supplied `noop` broker will do nothing.

    Please note that this is a broker created with the `create-broker` command,
    which is distinct from the broker types found on disk.
  HELP

  attr 'task', type: String, help: _(<<-HELP)
    The name of the task used to install nodes that match this policy.  This must
    match the selected repo, as it references files contained within that repository.
  HELP

  attr 'node_metadata', type: Hash, help: _(<<-HELP)
    Allows a policy to apply metadata to a node when it binds. This is NON
    AUTHORITATIVE in that it will not replace existing metadata on the node
    with the same keys it will only add keys that are missing.
  HELP

  def run(request, data)
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find(name: t)
    end.uniq

    data["repo"]   &&= Razor::Data::Repo[:name => data["repo"]]
    data["broker"] &&= Razor::Data::Broker[:name => data["broker"]]

    if data["task"]
      data["task_name"] = data.delete("task")
    end

    data["hostname_pattern"] = data.delete("hostname")

    # Handle positioning in the policy table
    if data.has_key?("before") or data.has_key?("after")
      position = data.has_key?("before") ? "before" : "after"
      neighbor = Razor::Data::Policy[:name => data.delete(position)]
    end

    data["enabled"] = true if data["enabled"].nil?

    # Create the policy
    policy, is_new = Razor::Data::Policy.import(data)

    if is_new
      tags.each { |t| policy.add_tag(t) }
      position and policy.move(position, neighbor)
      policy.save
    end

    return policy
  end

  def self.conform!(data)
    data.tap do |_|
      data['before'] = data['before']['name'] if data['before'].is_a?(Hash) and data['before'].keys == ['name']
      data['after'] = data['after']['name'] if data['after'].is_a?(Hash) and data['after'].keys == ['name']

      data['tags'] = Array[data['tags']] unless [NilClass, Array, Hash].include?(data['tags'].class)

      # Removed feature: Cannot create tags in create-policy
      if data['tags'].is_a?(Array) && data['tags'].any? {|tag_pair| tag_pair.is_a?(Hash) and tag_pair.keys == ['name', 'rule'] }
        raise Razor::ValidationFailure, _('this command can no longer create tags; see `razor help create-tag`')
      end
      
      # Conform {"name": "tagname"} into just "tagname"
      data['tags'] = data['tags'].map { |item| item.is_a?(Hash) && item.keys == ['name'] ? item['name'] : item } if data['tags'].is_a?(Array)

      data['repo'] = data['repo']['name'] if data['repo'].is_a?(Hash) and data['repo'].keys == ['name']
      data['broker'] = data['broker']['name'] if data['broker'].is_a?(Hash) and data['broker'].keys == ['name']
      data['task'] = data['task']['name'] if data['task'].is_a?(Hash) and data['task'].keys == ['name']
    end
  end
end
