# -*- encoding: utf-8 -*-

class Razor::Command::CreateTag < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true
  attr  'rule', type: Array

  def run(request, data)
    Razor::Data::Tag.find_or_create_with_rule(data)
  end
end

