# -*- encoding: utf-8 -*-
module Razor

  class TaskNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end
  class TaskInvalidError < RuntimeError; end

  # An task is a collection of templates, plus some metadata. The
  # task lives in a folder called +<task_name>.task+ The
  # metadata lives inside this folder in a YAML file called +metadata.yaml+.
  # The templates live in the task directory. For example, a task with name
  # +name+ must have its YAML metadata in +name.task/metadata.yaml+ somewhere on
  # +Razor.config["task_path"]+.
  #
  # Templates are looked up from the directories listed in
  # +Razor.config["task_path"]+, first in a subdirectory
  # +name.task+, then in the fixed directory +common+.
  #
  # The following entries from the YAML file are used:
  # +os_version+: the OS version this task supports
  # +label+, +description+: human-readable information
  # +boot_sequence+: a hash mapping integers or the string +"default"+ to
  # template names. When booting a node, the task will respond with
  # the numbered entries in +boot_sequence+ in order; if the number of boots
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
        raise TaskInvalidError, _("%{name} does not have an os_version") % {name: name}
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
      self.class.find_on_task_paths(Pathname(name + '.task') + filename) or
        (@base and @base.find_file(filename)) or
        self.class.find_common_file(filename) or
        raise TemplateNotFoundError, _("Task %{name}: %{filename} not on the search path") % {name: name, filename: filename}
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

    # Look up a task by name. We support file-based tasks
    # (mostly for development) and tasks stored in the database. If
    # there is both a file-based and a DB-backed task with the same
    # name, we use the file-based one.
    def self.find(name)
      if metadata_file = find_on_task_paths(Pathname(name + '.task') + 'metadata.yaml')
        metadata = YAML::load(File.read(metadata_file)) || {}
        new(name, metadata)
      elsif inst = Razor::Data::Task[:name => name]
        inst
      elsif is_legacy_format(name)
        # Migration error.
        raise raise TaskNotFoundError, _(<<-EOT) % {name: name}
Task %{name} appears to be in a legacy format:
We found a '%{name}.yaml' file, but modern tasks are in folders named '%{name}.task'
containing file 'metadata.yaml'.  For more detail see migration documentation online at
http://links.puppetlabs.com/razor-migration-task-revamp
EOT
      else
        raise TaskNotFoundError, _("Could not find task %{name} on the search path") % {name: name}
      end
    end

    def self.mk_task
      find('microkernel')
    end

    def self.noop_task
      find('noop')
    end

    def self.find_common_file(filename)
      find_on_task_paths(Pathname('common') + filename)
    end

    # List all known, valid tasks, both from the DB and the file
    # system. Return an array of +Razor::Task+ objects, sorted by
    # +name+
    def self.all
      (Razor.config.task_paths.map do |search_path|
        search_pathname = Pathname(search_path)
        Pathname.glob(Pathname(search_path) + '**' + '*.task').map do |task_folder_pathname|
          # Remove the base path and .task extension to get task name.
          task_folder_pathname.relative_path_from(search_pathname).sub_ext('').to_s
        end
      end + Razor::Data::Task.all.map(&:name)).flatten.sort.uniq.map do |name|
        begin
          find(name)
        rescue TaskInvalidError
          nil
        end
      end.compact
    end

    private
    def self.find_on_task_paths(file)
      Razor.config.task_paths.each do |task_path|
        fname = File::join(task_path, file)
        return fname if File::exists?(fname)
      end
      nil
    end

    private
    def self.is_legacy_format(name)
      return !find_on_task_paths(name + '.yaml').nil?
    end
  end
end
