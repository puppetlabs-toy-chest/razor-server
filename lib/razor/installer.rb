module Razor

  class InstallerNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end

  class Installer
    attr_reader :name, :os_version, :label, :description

    def initialize(metadata)
      if metadata["base"]
        @base = self.class.find(metadata["base"])
        metadata = @base.metadata.merge(metadata)
      end
      @metadata = metadata
      @name = metadata["name"]
      @os_version = metadata["os_version"].to_s
      @label = metadata["label"] || "#{@name} #{@os_version}"
      @description = metadata["description"] || ""
      @boot_seq = metadata["boot_sequence"]
    end

    def boot_template(node)
      @boot_seq[node.boot_count] || @boot_seq["default"]
    end

    def view_path(template)
      template += ".erb" unless template =~ /\.erb$/
      candidates = [ File::join(name, os_version, template),
                     File::join(name, template) ]
      if file = self.class.find_on_installer_paths(*candidates)
        File::dirname(file)
      elsif @base && file = @base.view_path(template)
        file
      elsif file = self.class.find_on_installer_paths(File::join("common", template))
        File::dirname(file)
      else
        raise TemplateNotFoundError, "Installer #{name}: #{template} not on the search path"
      end
    end

    def metadata
      @metadata
    end

    protected :metadata

    def self.find(name)
      yaml = find_on_installer_paths("#{name}.yaml")
      raise InstallerNotFoundError, "No installer #{name}.yaml on search path" unless yaml
      metadata = YAML::load(File::read(yaml))
      new(metadata)
    end

    def self.mk_installer
      find('microkernel')
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
