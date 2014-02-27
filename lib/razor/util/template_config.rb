# -*- encoding: utf-8 -*-
# A facade around Razor::Config for use in installer templates, so that the
# templates only have access to config settings that are explicitly
# whitelisted for them in Razor::Config::TEMPLATe_PATHS
module Razor::Util
  class ConfigAccessProhibited < RuntimeError; end

  class TemplateConfig
    def [](key)
      if Razor::Config::TEMPLATE_PATHS.include?(key)
        Razor.config[key]
      else
        raise ConfigAccessProhibited, _("The config setting '%{key}' can not be accessed from templates") % {key: key}
      end
    end
  end
end
