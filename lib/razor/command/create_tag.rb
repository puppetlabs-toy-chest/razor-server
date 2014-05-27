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
  attr  'name', type: String, required: true, size: 1..Float::INFINITY,
                help: _('The name of the tag.')

  attr 'rule', required: true, type: Array, help: _(<<-HELP)
    The tag matches a node if evaluating this run against the tag’s facts
    results in true. Note that tag matching is case sensitive.

    For example, here is a tag rule:

        ["or",
         ["=", ["fact", "macaddress"], "de:ea:db:ee:f0:00"]
         ["=", ["fact", "macaddress"], "de:ea:db:ee:f0:01"]]

    The tag could also be written like this:

        ["in", ["fact", "macaddress"], "de:ea:db:ee:f0:00", "de:ea:db:ee:f0:01"]

    The syntax for rule expressions is defined in `lib/razor/matcher.rb`.
    Expressions are of the form `[op arg1 arg2 .. argn]`
    where op is one of the operators below, and arg1 through argn are the
    arguments for the operator. If they are expressions themselves, they will
    be evaluated before `op` is evaluated.
  HELP

  def run(request, data)
    Razor::Data::Tag.import(data).first
  end
end

