# Facter Fact DHCP Server
#
# This fact adds facts for each dhcp enabled interace indicating the dhcp server
#
# It depends on the use of network manager and the availability of nmcli

nmcli = %x[ which nmcli ].chomp

if nmcli and not nmcli.empty? and File.executable?(nmcli)
  devices = %x[ #{nmcli} d | grep connected | awk "{print $1}" ].split("\n")
  
  devices.each { |d|
    dhcp = nil
    
    output = %x[ #{nmcli} d list iface #{d} ]
    dhcp = output.split("\n").select {|l| l =~ /dhcp_server_identifier/ }.to_s.match( /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/ ).to_s
    
    if dhcp
      Facter.add("dhcp_server_#{d}") do
        setcode do
          dhcp.to_s
        end
      end      
    end
  }
end
