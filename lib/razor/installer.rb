module Razor

  class InstallerNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end
  class InstallerInvalidError < RuntimeError; end

  # An installer is a collection of templates, plus some metadata. The
  # metadata lives in a YAML file, the templates in a subdirectory with the
  # same base name as the YAML file. For an installer with name +name+, the
  # YAML data must be in +name.yaml+ somewhere on
  # +Razor.config["installer_path"]+.
  #
  # Templates are looked up from the directories listed in
  # +Razor.config["installer_path"]+, first in a subdirectory
  # +name/os_version+, then +name+ and finally in the fixed directory
  # +common+.
  #
  # The following entries from the YAML file are used:
  # +os_version+: the OS version this installer supports
  # +label+, +description+: human-readable information
  # +boot_sequence+: a hash mapping integers or the string +"default"+ to
  # template names. When booting a node, the installer will respond with
  # the numered entries in +boot_sequence+ in order; if the number of boots
  # that a node has done under this installer is not in +boot_sequence+,
  # the template marked as +"default"+ will be used
  #
  # Installers can be derived from/based on other installers, by mentioning
  # their name in the +base+ metadata attribute. The metadata of the base
  # installer is used as default values for the derived installer. Having a
  # base installer also changes how templates are looked up: they are first
  # searched in the derived installer's template directories, then in those
  # of the base installer (and then its base installers), and finally in
  # the +common+ directory
  class Installer
    attr_reader :name, :os, :os_version, :boot_seq, :label, :description

    def initialize(name, metadata)
      if metadata["base"]
        @base = self.class.find(metadata["base"])
        metadata = @base.metadata.merge(metadata)
      end
      @metadata = metadata
      @name = name
      unless metadata["os_version"]
        raise InstallerInvalidError, "#{name} does not have an os_version"
      end
      @os = metadata["os"]
      @os_version = metadata["os_version"].to_s
      @label = metadata["label"] || "#{@name} #{@os_version}"
      @description = metadata["description"] || ""
      @boot_seq = metadata["boot_sequence"]
    end

    def boot_template(node)
      @boot_seq[node.boot_count] || @boot_seq["default"]
    end

    def find_template(template)
      template = template.sub(/\.erb$/, "")
      erb = template + ".erb"
      erb += ".erb" unless erb =~ /\.erb$/
      candidates = [ File::join(name, os_version, erb),
                     File::join(name, erb) ]
      if file = self.class.find_on_installer_paths(*candidates)
        [template.to_sym, { :views => File::dirname(file) }]
      elsif result = ((@base and @base.find_template(erb)) or
                      self.class.find_common_template(template, erb))
        result
      else
        raise TemplateNotFoundError, "Installer #{name}: #{template} not on the search path"
      end
    end

    def metadata
      @metadata
    end

    protected :metadata

    # Look up an installer by name. We support file-based installers
    # (mostly for development) and installers stored in the database. If
    # there is both a file-based and a DB-backed installer with the same
    # name, we use the file-based one.
    def self.find(name)
      if yaml = find_on_installer_paths("#{name}.yaml")
        metadata = YAML::load(File::read(yaml)) || {}
        new(name, metadata)
      elsif inst = Razor::Data::Installer[:name => name]
        inst
      else
        raise InstallerNotFoundError, "No installer #{name}.yaml on search path" unless yaml
      end
    end

    def self.mk_installer
      find('microkernel')
    end

    def self.find_common_template(template, erb = nil)
      erb ||= template + ".erb"
      if path = find_on_installer_paths(File::join("common", erb))
        [template.to_sym, { :views => File::dirname(path) }]
      end
    end

    private
    def self.find_on_installer_paths(*paths)
      Razor.config.installer_paths.each do |ip|
        paths.each do |path|
          fname = File::join(ip, path)
          return fname if File::exists?(fname)
        end
      end
      nil
    end
  end
end
