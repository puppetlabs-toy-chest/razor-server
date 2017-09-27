require 'master_manipulator'
require 'razor_integration'
test_name 'Configure TFTP Server for Razor'

#Checks to make sure environment is capable of running tests.
razor_config?
pe_version_check(master, 3.7, :fail)

step 'Pre-setup'
razor_server          = find_only_one(:razor_server)
razor_server_fqdn     = fact_on(razor_server, 'fqdn')

#Init
tftp_root_path        = '/var/lib/tftpboot/'
local_files_root_path = ENV['FILES'] || 'files'

ipxe_fw_source_path   = File.join(local_files_root_path, 'pxe', 'undionly.kpxe')
ipxe_fw_tftp_path     = File.join(tftp_root_path, 'pxelinux.0')
ipxe_script_razor_url = "https://#{razor_server_fqdn}:8151/api/microkernel/bootstrap?nic_max=1&http_port=8150"
ipxe_script_path      = File.join(tftp_root_path, 'default.ipxe')

#Setup
step 'Copy Custom iPXE Firmware to TFTP Server'
scp_to(razor_server, ipxe_fw_source_path, ipxe_fw_tftp_path)

step 'Generate Razor iPXE Script for TFTP Server'
curl_on(razor_server, "-k -o #{ipxe_script_path} \"#{ipxe_script_razor_url}\"")
