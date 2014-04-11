# -*- encoding: utf-8 -*-

class Razor::Command::CreateTag < Razor::Command
  summary "Create a new tag"
  description <<-EOT
Create a new tag, and set the rule it will use to match on facts and node
metadata.
  EOT

  example <<-EOT
Create a simple tag:

    {
      "name": "small",
      "rule": ["=", ["fact", "processorcount"], "2"]
    }

  EOT

  authz '%{name}'
  attr  'name', type: String, required: true, size: 1..Float::INFINITY
  attr  'rule', type: Array

  def run(request, data)
    Razor::Data::Tag.find_or_create_with_rule(data)
  end
end

