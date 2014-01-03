module Razor

  class RecipeNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end
  class RecipeInvalidError < RuntimeError; end

  # An recipe is a collection of templates, plus some metadata. The
  # metadata lives in a YAML file, the templates in a subdirectory with the
  # same base name as the YAML file. For an recipe with name +name+, the
  # YAML data must be in +name.yaml+ somewhere on
  # +Razor.config["recipe_path"]+.
  #
  # Templates are looked up from the directories listed in
  # +Razor.config["recipe_path"]+, first in a subdirectory
  # +name/os_version+, then +name+ and finally in the fixed directory
  # +common+.
  #
  # The following entries from the YAML file are used:
  # +os_version+: the OS version this recipe supports
  # +label+, +description+: human-readable information
  # +boot_sequence+: a hash mapping integers or the string +"default"+ to
  # template names. When booting a node, the recipe will respond with
  # the numered entries in +boot_sequence+ in order; if the number of boots
  # that a node has done under this recipe is not in +boot_sequence+,
  # the template marked as +"default"+ will be used
  #
  # Recipes can be derived from/based on other recipes, by mentioning
  # their name in the +base+ metadata attribute. The metadata of the base
  # recipe is used as default values for the derived recipe. Having a
  # base recipe also changes how templates are looked up: they are first
  # searched in the derived recipe's template directories, then in those
  # of the base recipe (and then its base recipes), and finally in
  # the +common+ directory
  class Recipe
    attr_reader :name, :os, :os_version, :boot_seq, :label, :description, :base, :architecture

    def initialize(name, metadata)
      if metadata["base"]
        @base = self.class.find(metadata["base"])
        metadata = @base.metadata.merge(metadata)
      end
      @metadata = metadata
      @name = name
      unless metadata["os_version"]
        raise RecipeInvalidError, "#{name} does not have an os_version"
      end
      @os = metadata["os"]
      @os_version = metadata["os_version"].to_s
      @label = metadata["label"] || "#{@name} #{@os_version}"
      @description = metadata["description"] || ""
      @architecture = metadata["architecture"] || ""
      @boot_seq = metadata["boot_sequence"]
    end

    def boot_template(node)
      @boot_seq[node.boot_count] || @boot_seq["default"]
    end

    def find_file(filename)
      candidates = [File::join(name, os_version, filename), File::join(name, filename)]
      self.class.find_on_recipe_paths(*candidates) or
        (@base and @base.find_file(filename)) or
        self.class.find_common_file(filename) or
        raise TemplateNotFoundError, "Recipe #{name}: #{filename} not on the search path"
    end

    def find_template(template)
      template = template.sub(/\.erb$/, "")
      erb      = template + ".erb"

      if file = find_file(erb)
        [template.to_sym, { :views => File::dirname(file) }]
      end
    end

    def metadata
      @metadata
    end

    protected :metadata

    # Look up an recipe by name. We support file-based recipes
    # (mostly for development) and recipes stored in the database. If
    # there is both a file-based and a DB-backed recipe with the same
    # name, we use the file-based one.
    def self.find(name)
      if yaml = find_on_recipe_paths("#{name}.yaml")
        metadata = YAML::load(File::read(yaml)) || {}
        new(name, metadata)
      elsif inst = Razor::Data::Recipe[:name => name]
        inst
      else
        raise RecipeNotFoundError, "No recipe #{name}.yaml on search path" unless yaml
      end
    end

    def self.mk_recipe
      find('microkernel')
    end

    def self.noop_recipe
      find('noop')
    end

    def self.find_common_file(filename)
      find_on_recipe_paths(File::join("common", filename))
    end

    # List all known recipes, both from the DB and the file
    # system. Return an array of +Razor::Recipe+ objects, sorted by
    # +name+
    def self.all
      (Razor.config.recipe_paths.map do |ip|
        Dir.glob(File::join(ip, "*.yaml")).map { |p| File::basename(p, ".yaml") }
       end + Razor::Data::Recipe.all).flatten.uniq.sort.map do |name|
        find(name)
      end
    end

    private
    def self.find_on_recipe_paths(*paths)
      Razor.config.recipe_paths.each do |ip|
        paths.each do |path|
          fname = File::join(ip, path)
          return fname if File::exists?(fname)
        end
      end
      nil
    end
  end
end
