module Razor::Data
  # This class represents recipes that are stored in the database, and
  # its main responsibility is to manage the persistence. The overall
  # recipe functionality is handled by the class +Razor::Recipe+,
  # which is the one to use for most recipe-related functionality.
  #
  # Note that we duck type this with Razor::Recipe so that they can be used
  # interchangeably for template lookup etc.
  class Recipe < Sequel::Model
    plugin :serialization, :json, :boot_seq
    plugin :serialization, :json, :templates

    def label
      "#{name} #{os_version}"
    end

    # These validations are too complex to do in the DB; we do them in Ruby
    # to have some amount of safety
    def validate
      super
      if templates.is_a?(Hash)
        templates.keys.all? { |k| k.is_a?(String) } or
          errors.add(:templates, "keys must be strings")
        templates.values.all? { |v| v.is_a?(String) } or
          errors.add(:templates, "values must be strings")
      else
        errors.add(:templates, "must be a Hash")
      end
      if boot_seq.is_a?(Hash)
        boot_seq.keys.all? { |k| k.is_a?(Integer) || k == "default" } or
          errors.add(:boot_seq, "keys must be integers or the string \"default\"")
        boot_seq.values.all? { |v| v.is_a?(String) } or
          errors.add(:boot_seq, "values must be strings")
      else
        errors.add(:boot_seq, "must be a Hash")
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
      elsif ((br = base_recipe) and (result = br.find_template(template)))
        result
      elsif result = Razor::Recipe.find_common_file(template + '.erb')
        [template.to_sym, { :views => File::dirname(result) }]
      else
        raise Razor::TemplateNotFoundError,
          "Recipe #{name}: no template '#{template}' for this recipe or its base recipes"
      end
    end

    private

    def base_recipe
      Recipe[:name => base] if base
    end
  end
end
