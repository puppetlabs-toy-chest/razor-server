module Razor

  class TaskNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end
  class TaskInvalidError < RuntimeError; end

  # An task is a collection of templates, plus some metadata. The
  # metadata lives in a YAML file, the templates in a subdirectory with the
  # same base name as the YAML file. For an task with name +name+, the
  # YAML data must be in +name.yaml+ somewhere on
  # +Razor.config["task_path"]+.
  #
  # Templates are looked up from the directories listed in
  # +Razor.config["task_path"]+, first in a subdirectory
  # +name/os_version+, then +name+ and finally in the fixed directory
  # +common+.
  #
  # The following entries from the YAML file are used:
  # +os_version+: the OS version this task supports
  # +label+, +description+: human-readable information
  # +boot_sequence+: a hash mapping integers or the string +"default"+ to
  # template names. When booting a node, the task will respond with
  # the numered entries in +boot_sequence+ in order; if the number of boots
  # that a node has done under this task is not in +boot_sequence+,
  # the template marked as +"default"+ will be used
  #
  # Tasks can be derived from/based on other tasks, by mentioning
  # their name in the +base+ metadata attribute. The metadata of the base
  # task is used as default values for the derived task. Having a
  # base task also changes how templates are looked up: they are first
  # searched in the derived task's template directories, then in those
  # of the base task (and then its base tasks), and finally in
  # the +common+ directory
  class Task
    attr_reader :name, :os, :os_version, :boot_seq, :label, :description, :base, :architecture

    def initialize(name, metadata)
      if metadata["base"]
        @base = self.class.find(metadata["base"])
        metadata = @base.metadata.merge(metadata)
      end
      @metadata = metadata
      @name = name
      unless metadata["os_version"]
        raise TaskInvalidError, "#{name} does not have an os_version"
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
      self.class.find_on_task_paths(*candidates) or
        (@base and @base.find_file(filename)) or
        self.class.find_common_file(filename) or
        raise TemplateNotFoundError, "Task #{name}: #{filename} not on the search path"
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

    # Look up an task by name. We support file-based tasks
    # (mostly for development) and tasks stored in the database. If
    # there is both a file-based and a DB-backed task with the same
    # name, we use the file-based one.
    def self.find(name)
      if yaml = find_on_task_paths("#{name}.yaml")
        metadata = YAML::load(File::read(yaml)) || {}
        new(name, metadata)
      elsif inst = Razor::Data::Task[:name => name]
        inst
      else
        raise TaskNotFoundError, "No task #{name}.yaml on search path" unless yaml
      end
    end

    def self.mk_task
      find('microkernel')
    end

    def self.noop_task
      find('noop')
    end

    def self.find_common_file(filename)
      find_on_task_paths(File::join("common", filename))
    end

    # List all known tasks, both from the DB and the file
    # system. Return an array of +Razor::Task+ objects, sorted by
    # +name+
    def self.all
      (Razor.config.task_paths.map do |ip|
        Dir.glob(File::join(ip, "*.yaml")).map { |p| File::basename(p, ".yaml") }
       end + Razor::Data::Task.all).flatten.uniq.sort.map do |name|
        find(name)
      end
    end

    private
    def self.find_on_task_paths(*paths)
      Razor.config.task_paths.each do |ip|
        paths.each do |path|
          fname = File::join(ip, path)
          return fname if File::exists?(fname)
        end
      end
      nil
    end
  end
end
