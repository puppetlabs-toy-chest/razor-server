module Razor

  class InstallerNotFoundError < RuntimeError; end
  class TemplateNotFoundError < RuntimeError; end

  class Installer
    attr_reader :name, :os_version, :label, :description

    def initialize(metadata)
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
      candidates = [ File::join(name, os_version), name, "common" ]
      template += ".erb" unless template =~ /\.erb$/
      Razor.config.installer_paths.each do |bp|
        candidates.each do |c|
          p = File::join(bp, c)
          return p if File::exists?(File::join(p, template))
        end
      end
      raise TemplateNotFoundError, "Installer #{name}: #{template} not on the search path"
    end

    def self.find(name)
      yaml = Razor.config.installer_paths.map { |ip|
        File::join(ip, "#{name}.yaml")
      }.find { |f| File::exists?(f) }
      raise InstallerNotFoundError, "No installer #{name}.yaml on search path" unless yaml
      metadata = YAML::load(File::read(yaml))
      new(metadata)
    end

    def self.mk_installer
      find('microkernel')
    end
  end
end
