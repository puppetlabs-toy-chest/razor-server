# -*- encoding: utf-8 -*-
module Razor::Data
  # This class represents tasks that are stored in the database, and
  # its main responsibility is to manage the persistence. The overall
  # task functionality is handled by the class +Razor::Task+,
  # which is the one to use for most task-related functionality.
  #
  # Note that we duck type this with Razor::Task so that they can be used
  # interchangeably for template lookup etc.
  class Task < Sequel::Model
    plugin :serialization, :json, :templates
    # Standard json serialization doesn't work here.
    # JSON serializes integers as strings, undo that
    serialize_attributes [
                         ->(b){ b.to_json },               # serialize
                         ->(b){
                           if b.is_a?(String)
                             b = JSON.parse(b)
                             b.keys.select { |k| k.is_a?(String) and k =~ /^[0-9]+$/ }.
                                 each { |k| b[k.to_i] = b.delete(k) }
                           end
                           b
                         } # deserialize
                         ], :boot_seq

    one_to_many :events, :key => :task_name, :primary_key => :name

    def label
      "#{name} #{os_version}"
    end

    # These validations are too complex to do in the DB; we do them in Ruby
    # to have some amount of safety
    def validate
      super
      if templates.is_a?(Hash)
        templates.keys.all? { |k| k.is_a?(String) } or
          errors.add(:templates, _("keys must be strings"))
        templates.values.all? { |v| v.is_a?(String) } or
          errors.add(:templates, _("values must be strings"))
      else
        errors.add(:templates, _("must be a Hash"))
      end
      if boot_seq.is_a?(Hash)
        boot_seq.keys.all? { |k| k.is_a?(Integer) || k == "default" } or
          errors.add(:boot_seq, _("keys must be integers or the string \"default\""))
        boot_seq.values.all? { |v| v.is_a?(String) } or
          errors.add(:boot_seq, _("values must be strings"))
      else
        errors.add(:boot_seq, _("must be a Hash"))
      end
    end

    # This is the same hack around auto_validation as in +Node+
    def schema_type_class(k)
      if k == :boot_seq or k == :templates
        Hash
      else
        super
      end
    end

    def boot_template(node)
      boot_seq[node.boot_count] || boot_seq["default"]
    end

    def find_template(template)
      if body = templates[template.to_s]
        [body, {}]
      elsif ((br = base_task) and (result = br.find_template(template)))
        result
      elsif result = Razor::Task.find_common_file(template + '.erb')
        [template.to_sym, { :views => File::dirname(result) }]
      else
        raise Razor::TemplateNotFoundError,
          _("Task %{name}: no template '%{template}' for this task or its base tasks") % {name: name, template: template}
      end
    end

    private

    def base_task
      Task[:name => base] if base
    end
  end
end
