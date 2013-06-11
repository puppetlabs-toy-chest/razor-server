module Razor
  module PolicyTemplate
    class Microkernel
      def ipxe
        # FIXME: default kernel and initrd need to be looked up from the DB
        kernel = "vmlinuz-mk"
        initrd = "initramfs-mk"

        image_svc_uri = Razor.config[:image_service_uri]
        debug_level = Razor.config["microkernel.debug_level"] || ""
        debug_level = '' unless ['quiet','debug'].include? debug_level
        kernel_args = Razor.config["microkernel.kernel_args"] || ""
        checkin_interval = Razor.config["checkin_interval"]

        boot_script = <<EOS
#!ipxe
kernel #{image_svc_uri}/#{kernel} maxcpus=1 #{debug_level} #{kernel_args} || goto error
initrd #{image_svc_uri}/#{initrd} || goto error
boot || goto error

:error
echo ERROR, will reboot in #{checkin_interval}s
sleep #{checkin_interval}
reboot
EOS
        boot_script
      end
    end
  end
end
