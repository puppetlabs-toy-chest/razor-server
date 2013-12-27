<#
  Net-DhcpDiscover.ps1
   
  Author: Chris Dent
  Date: 16/02/2010
  	31/10/2013 Simon Fuhrer add some options to the DiscoverPackage
   
  A script to send a DHCPDISCOVER request and report on DHCPOFFER 
  responses returned by all DHCP Servers on the current subnet.
   
  DHCP Packet Format (RFC 2131 - http://www.ietf.org/rfc/rfc2131.txt):
 
  0                   1                   2                   3
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |     op (1)    |   htype (1)   |   hlen (1)    |   hops (1)    |
  +---------------+---------------+---------------+---------------+
  |                            xid (4)                            |
  +-------------------------------+-------------------------------+
  |           secs (2)            |           flags (2)           |
  +-------------------------------+-------------------------------+
  |                          ciaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          yiaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          siaddr  (4)                          |
  +---------------------------------------------------------------+
  |                          giaddr  (4)                          |
  +---------------------------------------------------------------+
  |                                                               |
  |                          chaddr  (16)                         |
  |                                                               |
  |                                                               |
  +---------------------------------------------------------------+
  |                                                               |
  |                          sname   (64)                         |
  +---------------------------------------------------------------+
  |                                                               |
  |                          file    (128)                        |
  +---------------------------------------------------------------+
  |                                                               |
  |                          options (variable)                   |
  +---------------------------------------------------------------+
   
   FIELD      OCTETS       DESCRIPTION
   -----      ------       -----------
 
   op            1  Message op code / message type.
                    1 = BOOTREQUEST, 2 = BOOTREPLY
   htype         1  Hardware address type, see ARP section in "Assigned
                    Numbers" RFC; e.g., '1' = 10mb ethernet.
   hlen          1  Hardware address length (e.g.  '6' for 10mb
                    ethernet).
   hops          1  Client sets to zero, optionally used by relay agents
                    when booting via a relay agent.
   xid           4  Transaction ID, a random number chosen by the
                    client, used by the client and server to associate
                    messages and responses between a client and a
                    server.
   secs          2  Filled in by client, seconds elapsed since client
                    began address acquisition or renewal process.
   flags         2  Flags (see figure 2).
   ciaddr        4  Client IP address; only filled in if client is in
                    BOUND, RENEW or REBINDING state and can respond
                    to ARP requests.
   yiaddr        4  'your' (client) IP address.
   siaddr        4  IP address of next server to use in bootstrap;
                    returned in DHCPOFFER, DHCPACK by server.
   giaddr        4  Relay agent IP address, used in booting via a
                    relay agent.
   chaddr       16  Client hardware address.
   sname        64  Optional server host name, null terminated string.
   file        128  Boot file name, null terminated string; "generic"
                    name or null in DHCPDISCOVER, fully qualified
                    directory-path name in DHCPOFFER.
   options     var  Optional parameters field.  See the options
                    documents for a list of defined options.
#>
 
#
# Parameters
#
 
Param(
  # MAC Address String in Hex-Decimal Format can be delimited with 
  # dot, dash or colon (or none)
  [String]$MacAddressString = "AA:BB:CC:DD:EE:FF",
  # Length of time (in seconds) to spend waiting for Offers if
  # the connection does not timeout first
  [Byte]$DiscoverTimeout = 60
)
 
# Build a DHCPDISCOVER packet to send
#
# Caller: Main
 
Function New-DhcpDiscoverPacket
{
  Param(
    [String]$MacAddressString = "AA:BB:CC:DD:EE:FF"
  )
 
  # Generate a Transaction ID for this request
 
  $XID = New-Object Byte[] 4
  $Random = New-Object Random
  $Random.NextBytes($XID)
 
  # Convert the MAC Address String into a Byte Array
 
  # Drop any characters which might be used to delimit the string
  $MacAddressString = $MacAddressString -Replace "-|:|\."
  $MacAddress = [BitConverter]::GetBytes((
    [UInt64]::Parse($MacAddressString, 
    [Globalization.NumberStyles]::HexNumber)))
  # Reverse the MAC Address array
  [Array]::Reverse($MacAddress)
 
  # Create the Byte Array
  $DhcpDiscover = New-Object Byte[] 257
 
  # Copy the Transaction ID Bytes into the array
  [Array]::Copy($XID, 0, $DhcpDiscover, 4, 4)
   
  # Copy the MacAddress Bytes into the array (drop the first 2 bytes, 
  # too many bytes returned from UInt64)
  [Array]::Copy($MACAddress, 2, $DhcpDiscover, 28, 6)
 
  # Set the OP Code to BOOTREQUEST
  $DhcpDiscover[0] = 1
  # Set the Hardware Address Type to Ethernet
  $DhcpDiscover[1] = 1
  # Set the Hardware Address Length (number of bytes)
  $DhcpDiscover[2] = 6
  # Set the Broadcast Flag
  $DhcpDiscover[10] = 128
  # Set the Magic Cookie values
  $DhcpDiscover[236] = 99
  $DhcpDiscover[237] = 130
  $DhcpDiscover[238] = 83
  $DhcpDiscover[239] = 99
  # Set the DHCPDiscover Message Type Option
  $DhcpDiscover[240] = 53
  $DhcpDiscover[241] = 1
  $DhcpDiscover[242] = 1
  # Set Option Vendor
  $DhcpDiscover[243] = 60
  $DhcpDiscover[244] = 8
  $DhcpDiscover[245] = 77 #M
  $DhcpDiscover[246] = 83 #S
  $DhcpDiscover[247] = 70 #F
  $DhcpDiscover[248] = 84 #T
  $DhcpDiscover[249] = 32 # 
  $DhcpDiscover[250] = 53 #5
  $DhcpDiscover[251] = 46 #.
  $DhcpDiscover[252] = 48 #0
  # Set Option 175 as ipxe do retrieve also the bootstrap filename
  $DhcpDiscover[253] = 175 
  $DhcpDiscover[254] = 1
  # Set Option 255 End 
  $DhcpDiscover[255] = 255
  $DhcpDiscover[256] = 255

  Return $DhcpDiscover
}
 
# Parse a DHCP Packet, returning an object containing each field
# 
# Caller: Main
 
Function Read-DhcpPacket( [Byte[]]$Packet )
{
  $Reader = New-Object IO.BinaryReader(New-Object IO.MemoryStream(@(,$Packet)))
 
  $DhcpResponse = New-Object Object
 
  # Get and translate the Op code
  $DhcpResponse | Add-Member NoteProperty Op $Reader.ReadByte()
  if ($DhcpResponse.Op -eq 1) 
  { 
    $DhcpResponse.Op = "BootRequest"
  } 
  else 
  { 
    $DhcpResponse.Op = "BootResponse"
  }
 
  $DhcpResponse | Add-Member NoteProperty HType -Value $Reader.ReadByte()
  if ($DhcpResponse.HType -eq 1) { $DhcpResponse.HType = "Ethernet" }
 
  $DhcpResponse | Add-Member NoteProperty HLen $Reader.ReadByte()
  $DhcpResponse | Add-Member NoteProperty Hops $Reader.ReadByte()
  $DhcpResponse | Add-Member NoteProperty XID $Reader.ReadUInt32()
  $DhcpResponse | Add-Member NoteProperty Secs $Reader.ReadUInt16()
  $DhcpResponse | Add-Member NoteProperty Flags $Reader.ReadUInt16()
  # Broadcast is the only flag that can be present, the other bits are reserved
  if ($DhcpResponse.Flags -BAnd 128) { $DhcpResponse.Flags = @("Broadcast") }
 
  $DhcpResponse | Add-Member NoteProperty CIAddr `
    $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
    "$($Reader.ReadByte()).$($Reader.ReadByte())")
  $DhcpResponse | Add-Member NoteProperty YIAddr `
    $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
    "$($Reader.ReadByte()).$($Reader.ReadByte())")
  $DhcpResponse | Add-Member NoteProperty SIAddr `
    $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
    "$($Reader.ReadByte()).$($Reader.ReadByte())")
  $DhcpResponse | Add-Member NoteProperty GIAddr `
    $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
    "$($Reader.ReadByte()).$($Reader.ReadByte())")
 
  $MacAddrBytes = New-Object Byte[] 16
  [Void]$Reader.Read($MacAddrBytes, 0, 16)
  $MacAddress = [String]::Join(
    ":", $($MacAddrBytes[0..5] | %{ [String]::Format('{0:X2}', $_) }))
  $DhcpResponse | Add-Member NoteProperty CHAddr $MacAddress
 
  $DhcpResponse | Add-Member NoteProperty SName `
    $([String]::Join("", $Reader.ReadChars(64)).Trim())
  $DhcpResponse | Add-Member NoteProperty File `
    $([String]::Join("", $Reader.ReadChars(128)).Trim())
 
  $DhcpResponse | Add-Member NoteProperty MagicCookie `
    $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
    "$($Reader.ReadByte()).$($Reader.ReadByte())")
 
  # Start reading Options
 
  $DhcpResponse | Add-Member NoteProperty Options @()
  While ($Reader.BaseStream.Position -lt $Reader.BaseStream.Length)
  {
    $Option = New-Object Object
    $Option | Add-Member NoteProperty OptionCode $Reader.ReadByte()
    $Option | Add-Member NoteProperty OptionName ""
    $Option | Add-Member NoteProperty Length 0
    $Option | Add-Member NoteProperty OptionValue ""
 
    If ($Option.OptionCode -ne 0 -And $Option.OptionCode -ne 255)
    {
      $Option.Length = $Reader.ReadByte()
    }
 
    Switch ($Option.OptionCode)
    {
      0 { $Option.OptionName = "PadOption" }
      1 {
        $Option.OptionName = "SubnetMask"
        $Option.OptionValue = `
          $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
          "$($Reader.ReadByte()).$($Reader.ReadByte())") }
      3 {
        $Option.OptionName = "Router"
        $Option.OptionValue = `
          $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
          "$($Reader.ReadByte()).$($Reader.ReadByte())") }
      6 {
        $Option.OptionName = "DomainNameServer"
        $Option.OptionValue = @()
        For ($i = 0; $i -lt ($Option.Length / 4); $i++) 
        { 
          $Option.OptionValue += `
            $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
            "$($Reader.ReadByte()).$($Reader.ReadByte())")
        } }
      15 {
        $Option.OptionName = "DomainName"
        $Option.OptionValue = [String]::Join(
          "", $Reader.ReadChars($Option.Length)) }
      51 {
        $Option.OptionName = "IPAddressLeaseTime"
        # Read as Big Endian
        $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
          ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
          ($Reader.ReadByte() * 256) + `
          $Reader.ReadByte()
        $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
      53 { 
        $Option.OptionName = "DhcpMessageType"
        Switch ($Reader.ReadByte())
        {
          1 { $Option.OptionValue = "DHCPDISCOVER" }
          2 { $Option.OptionValue = "DHCPOFFER" }
          3 { $Option.OptionValue = "DHCPREQUEST" }
          4 { $Option.OptionValue = "DHCPDECLINE" }
          5 { $Option.OptionValue = "DHCPACK" }
          6 { $Option.OptionValue = "DHCPNAK" }
          7 { $Option.OptionValue = "DHCPRELEASE" }
        } }
      54 {
        $Option.OptionName = "DhcpServerIdentifier"
        $Option.OptionValue = `
          $("$($Reader.ReadByte()).$($Reader.ReadByte())." + `
          "$($Reader.ReadByte()).$($Reader.ReadByte())") }
      58 {
        $Option.OptionName = "RenewalTime"
        # Read as Big Endian
        $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
          ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
          ($Reader.ReadByte() * 256) + `
          $Reader.ReadByte()
        $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
      59 {
        $Option.OptionName = "RebindingTime"
        # Read as Big Endian
        $Value = ($Reader.ReadByte() * [Math]::Pow(256, 3)) + `
          ($Reader.ReadByte() * [Math]::Pow(256, 2)) + `
          ($Reader.ReadByte() * 256) + `
          $Reader.ReadByte()
        $Option.OptionValue = $(New-TimeSpan -Seconds $Value) }
      255 { $Option.OptionName = "EndOption" }
      default {
        # For all options which are not decoded here
        $Option.OptionName = "NoOptionDecode"
        $Buffer = New-Object Byte[] $Option.Length
        [Void]$Reader.Read($Buffer, 0, $Option.Length)
        $Option.OptionValue = $Buffer
      }
    }
   
    # Override the ToString method
    $Option | Add-Member ScriptMethod ToString `
        { Return "$($this.OptionName) ($($this.OptionValue))" } -Force
 
    $DhcpResponse.Options += $Option
  }
   
  Return $DhcpResponse
}
 
# Create a UDP Socket with Broadcast and Address Re-use enabled.
#
# Caller: Main
 
Function New-UdpSocket
{
  Param(
    [Int32]$SendTimeOut = 5,
    [Int32]$ReceiveTimeOut = 5
  )
   
  $UdpSocket = New-Object Net.Sockets.Socket(
    [Net.Sockets.AddressFamily]::InterNetwork, 
    [Net.Sockets.SocketType]::Dgram,
    [Net.Sockets.ProtocolType]::Udp)
  $UdpSocket.EnableBroadcast = $True
  $UdpSocket.ExclusiveAddressUse = $False
  $UdpSocket.SendTimeOut = $SendTimeOut * 1000
  $UdpSocket.ReceiveTimeOut = $ReceiveTimeOut * 1000
   
  Return $UdpSocket
}
 
# Close down a Socket
#
# Caller: Main
 
Function Remove-Socket
{
  Param(
    [Net.Sockets.Socket]$Socket
  )
   
  $Socket.Shutdown("Both")
  $Socket.Close()
}
 
#
# Main
#
 
# Create a Byte Array for the DHCPDISCOVER packet
$Message = New-DhcpDiscoverPacket -Send 10 -Receive 10
 
# Create a socket
$UdpSocket = New-UdpSocket
 
# UDP Port 68 (Server-to-Client port)
$EndPoint = [Net.EndPoint](
  New-Object Net.IPEndPoint($([Net.IPAddress]::Any, 68)))
# Listen on $EndPoint
$UdpSocket.Bind($EndPoint)
 
# UDP Port 67 (Client-to-Server port)
$EndPoint = [Net.EndPoint](
 New-Object Net.IPEndPoint($([Net.IPAddress]::Broadcast, 67)))
# Send the DHCPDISCOVER packet
$BytesSent = $UdpSocket.SendTo($Message, $EndPoint)
 
# Begin receiving and processing responses
$NoConnectionTimeOut = $True
 
$Start = Get-Date
 
While ($NoConnectionTimeOut)
{
  $BytesReceived = 0
  Try
  {
    # Placeholder EndPoint for the Sender
    $SenderEndPoint = [Net.EndPoint](
      New-Object Net.IPEndPoint($([Net.IPAddress]::Any, 0)))
    # Receive Buffer
    $ReceiveBuffer = New-Object Byte[] 1024
    $BytesReceived = $UdpSocket.ReceiveFrom($ReceiveBuffer, [Ref]$SenderEndPoint)
  }
  #
  # Catch a SocketException, thrown when the Receive TimeOut value is reached
  #
  Catch [Net.Sockets.SocketException]
  {
    $NoConnectionTimeOut = $False
  }
   
  If ($BytesReceived -gt 0)
  {
    Read-DhcpPacket $ReceiveBuffer[0..$BytesReceived]
  }
   
  If ((Get-Date) -gt $Start.AddSeconds($DiscoverTimeout))
  {
    # Exit condition, not error condition
    $NoConnectionTimeOut = $False
  }
}
 
Remove-Socket $UdpSocket