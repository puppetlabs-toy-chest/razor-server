# -*- encoding: utf-8 -*-

class Razor::Command::CreatePolicy < Razor::Command
  authz  '%{name}'
  attr   'name',          type: String, required: true
  attr   'hostname',      type: String, required: true
  attr   'root_password', type: String

  object 'before', exclude: 'after' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  object 'after', exclude: 'before' do
    attr 'name', type: String, required: true, references: Razor::Data::Policy
  end

  array 'tags' do
    object do
      attr 'name', type: String, required: true, references: Razor::Data::Tag
    end
  end

  object 'repo' do
    attr 'name', type: String, required: true, references: Razor::Data::Repo
  end

  object 'broker' do
    attr 'name', type: String, required: true, references: Razor::Data::Broker
  end

  object 'task' do
    attr 'name', type: String, required: true
  end

  def run(request, data)
    tags = (data.delete("tags") || []).map do |t|
      Razor::Data::Tag.find_or_create_with_rule(t)
    end

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

    # Create the policy
    policy = Razor::Data::Policy.new(data).save
    tags.each { |t| policy.add_tag(t) }
    position and policy.move(position, neighbor)
    policy.save

    return policy
  end
end
