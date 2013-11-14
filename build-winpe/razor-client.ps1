# -*- powershell -*-

# If we have a configuration file, source it in.
$configfile = join-path $env:SYSTEMDRIVE "razor-client-config.ps1"
if (test-path $configfile) {
    write-host "sourcing configuration from $configfile"
    . $configfile
    # $server is now set
} else {
    # No sign of a configuration file, guess that our DHCP server is also our
    # Razor server, and point at that.  Could easily be wrong, but what else
    # are we going to do? --daniel 2013-10-28
    #
    # @todo danielp 2013-10-29: is there a better way to handle multiple
    # network adapters with DHCP addresses than I have here?
    write-host "guessing that DHCP server == Razor server!"
    $server = get-wmiobject win32_networkadapterconfiguration |
                  where { $_.ipaddress -and
                          $_.dhcpenabled -eq "true" -and
                          $_.dhcpleaseobtained } |
                  select -uniq -first 1 -expandproperty dhcpserver

}

$baseurl = "http://${server}:8080/svc"


# Figure out our node hardware ID details, since we can't get at anything more
# useful from our boot environment.  Sadly, rediscovery is the order of the
# day here.  Damn WinPE.
$hwid = get-wmiobject Win32_NetworkAdapter -filter "netenabled='true'" | `
            select -expandproperty macaddress | `
            foreach-object -begin { $n = 0 } -process { $n++; "net${n}=${_}"; }
$hwid = $hwid -join '&' -replace ':', '-'

# Now, communicate with the server and translate our HWID into a node ID
# number that we can use for our next step -- accessing our bound
# installer templates.
write-host "contact ${baseurl}/nodeid?${hwid} for ID mapping"
$data = invoke-restmethod "${baseurl}/nodeid?${hwid}"
$id = $data.id
write-host "mapped myself to node ID ${id}"

# Finally, fetch down our next stage of script and evaluate it.
# Apparently this is the best way to just get the string; certainly, it beats
# the results from `invoke-webrequest` and friends for sanity.
$url = "${baseurl}/file/${id}/second-stage.ps1"
write-host "load and execute ${url}"
(new-object System.Net.WebClient).DownloadString($url) | invoke-expression

# ...and we are done.
write-host "second stage completed, exiting."
exit
