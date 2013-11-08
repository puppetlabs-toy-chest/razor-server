<<<<<<< HEAD
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
=======
$sourcetftpclient = @'
using System;
using System.Text;
using System.IO;
using System.Net;
using System.Net.Sockets;
 public class TFTPClient
    {

        #region -=[ Declarations ]=-

        /// <summary>
        /// TFTP opcodes
        /// </summary>
        public enum Opcodes
        {
            Unknown = 0,
            Read = 1,
            Write = 2,
            Data = 3,
            Ack = 4,
            Error = 5
        }

        /// <summary>
        /// TFTP modes
        /// </summary>
        public enum Modes
        {
            Unknown = 0,
            NetAscii = 1,
            Octet = 2,
            Mail = 3
        }

        /// <summary>
        /// A TFTP Exception
        /// </summary>
        public class TFTPException : Exception
        {

            public string ErrorMessage = "";
            public int ErrorCode = -1;

            /// <summary>
            /// Initializes a new instance of the <see cref="TFTPException"/> class.
            /// </summary>
            /// <param name="errCode">The err code.</param>
            /// <param name="errMsg">The err MSG.</param>
            public TFTPException(int errCode, string errMsg)
            {
                ErrorCode = errCode;
                ErrorMessage = errMsg;
            }

            /// <summary>
            /// Creates and returns a string representation of the current exception.
            /// </summary>
            /// <returns>
            /// A string representation of the current exception.
            /// </returns>
            /// <filterPriority>1</filterPriority>
            /// <permissionSet class="System.Security.permissionSet" version="1">
            ///   <IPermission class="System.Security.Permissions.FileIOPermission, mscorlib, Version=2.0.3600.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" version="1" PathDiscovery="*AllFiles*"/>
            /// </permissionSet>
            public override string ToString()
            {
                return String.Format("TFTPException: ErrorCode: {0} Message: {1}", ErrorCode, ErrorMessage);
            }
        }

        private int tftpPort;
        private string tftpServer = "";
        #endregion

        #region -=[ Ctor ]=-

        /// <summary>
        /// Initializes a new instance of the <see cref="TFTPClient"/> class.
        /// </summary>
        /// <param name="server">The server.</param>
        public TFTPClient(string server)
            : this(server, 69)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="TFTPClient"/> class.
        /// </summary>
        /// <param name="server">The server.</param>
        /// <param name="port">The port.</param>
        public TFTPClient(string server, int port)
        {
            Server = server;
            Port = port;

        }

        #endregion

        #region -=[ Public Properties ]=-

        /// <summary>
        /// Gets the port.
        /// </summary>
        /// <value>The port.</value>
        public int Port
        {
            get { return tftpPort; }
            private set { tftpPort = value; }
        }

        /// <summary>
        /// Gets the server.
        /// </summary>
        /// <value>The server.</value>
        public string Server
        {
            get { return tftpServer; }
            private set { tftpServer = value; }
        }

        #endregion

        #region -=[ Public Member ]=-

        /// <summary>
        /// Gets the specified remote file.
        /// </summary>
        /// <param name="remoteFile">The remote file.</param>
        /// <param name="localFile">The local file.</param>
        public void Get(string remoteFile, string localFile)
        {
            Get(remoteFile, localFile, Modes.Octet);
        }

        /// <summary>
        /// Gets the specified remote file.
        /// </summary>
        /// <param name="remoteFile">The remote file.</param>
        /// <param name="localFile">The local file.</param>
        /// <param name="tftpMode">The TFTP mode.</param>
        public void Get(string remoteFile, string localFile, Modes tftpMode)
        {
            int len = 0;
            int packetNr = 1;
            byte[] sndBuffer = CreateRequestPacket(Opcodes.Read, remoteFile, tftpMode);
            byte[] rcvBuffer = new byte[516];

            BinaryWriter fileStream = new BinaryWriter(new FileStream(localFile, FileMode.Create, FileAccess.Write, FileShare.Read));
            IPHostEntry hostEntry = Dns.GetHostEntry(tftpServer);
            IPEndPoint serverEP = new IPEndPoint(hostEntry.AddressList[0], tftpPort);
            EndPoint dataEP = (EndPoint)serverEP;
            Socket tftpSocket = new Socket(serverEP.Address.AddressFamily, SocketType.Dgram, ProtocolType.Udp);

            // Request and Receive first Data Packet From TFTP Server
            tftpSocket.SendTo(sndBuffer, sndBuffer.Length, SocketFlags.None, serverEP);
            tftpSocket.ReceiveTimeout = 1000;
            len = tftpSocket.ReceiveFrom(rcvBuffer, ref dataEP);

            // keep track of the TID 
            serverEP.Port = ((IPEndPoint)dataEP).Port;

            while (true)
            {
                // handle any kind of error 
                if (((Opcodes)rcvBuffer[1]) == Opcodes.Error)
                {
                    fileStream.Close();
                    tftpSocket.Close();
                    throw new TFTPException(((rcvBuffer[2] << 8) & 0xff00) | rcvBuffer[3], Encoding.ASCII.GetString(rcvBuffer, 4, rcvBuffer.Length - 5).Trim('\0'));
                }
                // expect the next packet
                if ((((rcvBuffer[2] << 8) & 0xff00) | rcvBuffer[3]) == packetNr)
                {
                    // Store to local file
                    fileStream.Write(rcvBuffer, 4, len - 4);

                    // Send Ack Packet to TFTP Server
                    sndBuffer = CreateAckPacket(packetNr++);
                    tftpSocket.SendTo(sndBuffer, sndBuffer.Length, SocketFlags.None, serverEP);
                }
                // Was ist the last packet ?
                if (len < 516)
                {
                    break;
                }
                else
                {
                    // Receive Next Data Packet From TFTP Server
                    len = tftpSocket.ReceiveFrom(rcvBuffer, ref dataEP);
                }
            }

            // Close Socket and release resources
            tftpSocket.Close();
            fileStream.Close();
        }



        #endregion

        #region -=[ Private Member ]=-

        /// <summary>
        /// Creates the request packet.
        /// </summary>
        /// <param name="opCode">The op code.</param>
        /// <param name="remoteFile">The remote file.</param>
        /// <param name="tftpMode">The TFTP mode.</param>
        /// <returns>the ack packet</returns>
        private byte[] CreateRequestPacket(Opcodes opCode, string remoteFile, Modes tftpMode)
        {
            // Create new Byte array to hold Initial 
            // Read Request Packet
            int pos = 0;
            string modeAscii = tftpMode.ToString().ToLowerInvariant();
            byte[] ret = new byte[modeAscii.Length + remoteFile.Length + 4];

            // Set first Opcode of packet to indicate
            // if this is a read request or write request
            ret[pos++] = 0;
            ret[pos++] = (byte)opCode;

            // Convert Filename to a char array
            pos += Encoding.ASCII.GetBytes(remoteFile, 0, remoteFile.Length, ret, pos);
            ret[pos++] = 0;
            pos += Encoding.ASCII.GetBytes(modeAscii, 0, modeAscii.Length, ret, pos);
            ret[pos] = 0;

            return ret;
        }

        /// <summary>
        /// Creates the data packet.
        /// </summary>
        /// <param name="packetNr">The packet nr.</param>
        /// <param name="data">The data.</param>
        /// <returns>the data packet</returns>
        private byte[] CreateDataPacket(int blockNr, byte[] data)
        {
            // Create Byte array to hold ack packet
            byte[] ret = new byte[4 + data.Length];

            // Set first Opcode of packet to TFTP_ACK
            ret[0] = 0;
            ret[1] = (byte)Opcodes.Data;
            ret[2] = (byte)((blockNr >> 8) & 0xff);
            ret[3] = (byte)(blockNr & 0xff);
            Array.Copy(data, 0, ret, 4, data.Length);
            return ret;
        }

        /// <summary>
        /// Creates the ack packet.
        /// </summary>
        /// <param name="blockNr">The block nr.</param>
        /// <returns>the ack packet</returns>
        private byte[] CreateAckPacket(int blockNr)
        {
            // Create Byte array to hold ack packet
            byte[] ret = new byte[4];

            // Set first Opcode of packet to TFTP_ACK
            ret[0] = 0;
            ret[1] = (byte)Opcodes.Ack;

            // Insert block number into packet array
            ret[2] = (byte)((blockNr >> 8) & 0xff);
            ret[3] = (byte)(blockNr & 0xff);
            return ret;
        }

        #endregion
    }
'@

Function HTTPRequest($url){
    $webclient = New-Object System.Net.WebClient
    $s = $webclient.DownloadString($url)
    $s = $s.Split([Environment]::NewLine)
    $s
}


Add-Type -TypeDefinition $sourcetftpclient 



Function Write-ToConsole([string]$text,[string]$value){
    Write-Host -NoNewline -ForegroundColor White $text
    Write-Host -ForegroundColor Yellow $value
}
$RazorDir = "$env:SystemDrive\Razor"
write-host -foreground green "Starting Discover Razor Server"

$hwid = get-wmiobject Win32_NetworkAdapter -filter "netenabled='true'" | `
            select -expandproperty macaddress | `
            foreach-object -begin { $n = 0 } -process { $n++; "net${n}=${_}"; }
            $hwid = $hwid -join '&' -replace ':', '-'
Write-ToConsole "HWID: " $hwid

$macaddressesarrays = @((get-wmiobject Win32_NetworkAdapter -filter "netenabled='true'" | select -expandproperty macaddress) -replace ":","-")

for ($cnt=0; $cnt -le $macaddressesarrays.Length; $cnt++) {
    New-Variable -name  "net$cnt" -value $macaddressesarrays[$cnt]
}

$dhcp_mac = $net0
Write-ToConsole "DHCP MAC: " $dhcp_mac
$uuid = $hwid 
$RazorDir = "$env:SystemDrive\Razor"
$command1 = "$RazorDir\Net-DhcpDiscover.ps1"


$dhcpresponse = Invoke-Expression $command1
if ($dhcpresponse -ne $null){
    $dhcpserver = ($dhcpresponse.Options | where{$_.OptionCode -eq 54}).optionValue
    $tftpserver=$dhcpserver # Set initial to the same as the dhpc server
    [string]$razorbootstrapfilename = $dhcpresponse.File.Replace("`0","")


    $op66 = $dhcpresponse.options | where{$_.OptionCode -eq 66}
    if ($op66 -ne $null){
        # 66 = TFTP Server
        $tftpserver=""
        $op66.optionValue | foreach{[string]$tftpserver+=[char]$_}
    }
    Write-ToConsole "DHCP Server: " $dhcpserver
    Write-ToConsole "TFTP Server: " $tftpserver
    Write-ToConsole "Razor Bootstrap Filename: " $razorbootstrapfilename

    [TFTPClient]$tftpclient  = new-object TFTPClient $tftpserver
    Write-ToConsole "Download Bootstrap file to: " $RazorDir
    $fulllocalfilename = join-path $RazorDir $razorbootstrapfilename
    $tftpclient.Get($razorbootstrapfilename,$fulllocalfilename);
    if (test-path $fulllocalfilename){
        Write-ToConsole "Succesfully downloaded: " $fulllocalfilename
        $ipxecontent = get-content $fulllocalfilename
        if ($ipxecontent[0] -eq "#!ipxe"){
            $chainline = $ipxecontent | where{$_.Startswith("chain http")}
            $baseurl = $chainline.Substring($chainline.IndexOf("http://"),$chainline.IndexOf("svc")-3)
	    $querynodeidurl = "${baseurl}/nodeid?${hwid}"
            Write-ToConsole "Contacting Razor for ID mapping: " $querynodeidurl
	    try{
	      $data = invoke-restmethod "${baseurl}/nodeid?${hwid}"
	      $nodeid = $data.id
	      Write-ToConsole "mapped myself to node ID: " $nodeid
	      # Finally, fetch down our next stage of script and evaluate it.
	      # Apparently this is the best way to just get the string; certainly, it beats
	      # the results from `invoke-webrequest` and friends for sanity.
	      $scriptfilename = "unattended.ps1"
	      $urlunattened = "${baseurl}/file/${nodeid}/${scriptfilename}"
	      $localfilename = join-path $RazorDir $scriptfilename
	      $webclient = New-Object System.Net.WebClient
	      $webclient.DownloadFile($urlunattened,$localfilename)
	      Write-ToConsole "Razor-Client downloaded $scriptfilename File, invoke File now: " $localfilename
	      Invoke-Expression $localfilename
	    }catch[Exception]{
	      write-error $_
	    }

        }
    }

}else{
    write-error "No DHCP offer received!"
}
write-host -foreground green "Deployment Done"
exit
>>>>>>> 205164f3741caff07d97571b5a58d60bedcf92e2
