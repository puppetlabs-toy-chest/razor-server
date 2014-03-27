# -*- encoding: utf-8 -*-

class Razor::Command::CreateTask < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true
  attr  'os',   type: String, required: true

  object 'templates', required: true do
    extra_attrs type: String
  end

  object 'boot_seq' do
    attr 'default', type: String
    extra_attrs /^[0-9]+/, type: String
  end

  def run(request, data)
    # If boot_seq is not a Hash, the model validation for tasks
    # will catch that, and will make saving the task fail
    if (boot_seq = data["boot_seq"]).is_a?(Hash)
      # JSON serializes integers as strings, undo that
      boot_seq.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
        each { |k| boot_seq[k.to_i] = boot_seq.delete(k) }
    end

    Razor::Data::Task.new(data).save.freeze
  end
end
