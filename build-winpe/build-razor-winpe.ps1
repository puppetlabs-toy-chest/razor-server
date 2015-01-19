# -*- powershell -*-
# Run this script as:
#   powershell -executionpolicy bypass -file build-razor-winpe.ps1 \
#     -razorurl http://razor:8080/svc -workdir C:\build-winpe
#
# Produce a WinPE image suitable for use with Razor

# Parameters
#   - razorurl: the URL of the Razor server, something like
#     http://razor-server:8080/svc (note the /svc at the end, not /api)
#   - workdir: where to create the WinPE image and intermediate files
#              Defaults to the directory containing this script
param([String] $workdir, [Parameter(Mandatory=$true)][String] $razorurl)

function test-administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function get-currentdirectory {
    $thisName = $MyInvocation.MyCommand.Name
    [IO.Path]::GetDirectoryName((Get-Content function:$thisName).File)
}


if (-not (test-administrator)) {
    write-error @"
You must be running as administrator for this script to function.
Unfortunately, we can't reasonable elevate privileges ourselves
so you need to launch an administrator mode command shell and then
re-run this script yourself.
"@
    exit 1
}

# Validate the razorurl
$uri = $razorurl -as [System.Uri]
if (-not $uri.scheme -eq 'http' -or -not $uri.scheme -eq 'https') {
  write-error "razor-url must be a http or https URL"
  exit 1
}
if (-not $uri.AbsolutePath.split('/')[-1] -eq 'svc') {
  write-error "razor-url must end with '/svc'"
  exit 1
}

# Basic location stuff...
$cwd = get-currentdirectory
if ($workdir -eq "") {
    $workdir = $cwd
}

$output = join-path $workdir "razor-winpe"
$mount  = join-path $workdir "razor-winpe-mount"


########################################################################
# Some "constants" that might have to change to accomodate different
# versions of of the WinPE building tools or whatever.  These are
# factored out mostly for my convenience, honestly.

# The ADK versions we can deal with. Different versions unfortunately
# require slightly different handling
$adkversions = @('8.1', '8.0')

foreach ($adkversion in $adkversions) {
    # Default install root for the ADK; since the installer database
    # does not contain custom paths, if any, this was installed to,
    # we are stuck with just defaulting and failing.
    $adk = @([Environment]::GetFolderPath('ProgramFilesX86'),
             [Environment]::GetFolderPath('ProgramFiles')) |
           % { join-path $_ "Windows Kits\$adkversion\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64" } |
           ? { test-path  $_ } |
           select-object -First 1
    if ($adk -ne $null) { break }
}
if ($adk -eq $null) {
    write-error @"
We could not find the ADK - either it is not installed or not installed in
the default location.
"@
    exit 1
}

$env:PSModulePath = ($env:PSModulePath + ";$adk\..\..\Deployment Tools\amd64")

# Path to the clean WinPE WIM file.
$wim = join-path $adk "en-us\winpe.wim"

# Root for the CAB files for optional features.
$packages = join-path $adk "WinPE_OCs"


########################################################################
# ...and these are "constants" that are calculated from the above.
write-host "* Make sure our working and output directories exist."
if (test-path -path $output) {
    write-error "Output path $output already exists, delete these folders and try again!"
    exit 1
} else {
    new-item -type directory $output
}

if (-not(test-path -path $mount)) {
    new-item -type directory $mount
}


write-host "* Copy the clean ADK WinPE image into our output area."
copy-item $wim $output
# update our wim location...
$wim = join-path $output "winpe.wim"



import-module dism

write-host "* Mounting the wim image"
mount-windowsimage -imagepath $wim -index 1 -path $mount -erroraction stop

write-host "* Adding powershell, and dependencies, to the image"
# This order is documented in http://technet.microsoft.com/library/hh824926.aspx
# I guess you can't change it safely, so respect that.
if ($adkversion -eq '8.0') {
  $cabs = @('WinPE-WMI', 'WinPE-NetFX4', 'WinPE-Scripting', 'WinPE-PowerShell3')
} elseif ($adkversion -eq '8.1') {
  $cabs = @('WinPE-WMI', 'WinPE-NetFX', 'WinPE-Scripting', 'WinPE-PowerShell')
} else {
  write-error "We can not deal with ADK version $adkversion"
  exit 1
}

foreach ($cab in $cabs ) {
    write-host "** Installing $cab to image"
    # there must be a way to do this without a temporary variable
    $pkg = join-path $packages "$cab.cab"
    add-windowspackage -packagepath $pkg -path $mount
}

write-host "* Writing startup PowerShell script"
$file   = join-path $mount "razor-client.ps1"
$client = join-path $cwd "razor-client.ps1"
copy-item $client $file

$file   = join-path $mount "razor-client-config.ps1"
set-content $file @"
`$baseurl = "$razorurl"
"@

write-host "* Writing Windows\System32\startnet.cmd script"
$file = join-path $mount "Windows\System32\startnet.cmd"
set-content $file @"
@echo off
echo starting wpeinit to detect and boot network hardware
wpeinit
echo starting the razor client
powershell -executionpolicy bypass -noninteractive -file %SYSTEMDRIVE%\razor-client.ps1
echo dropping to a command shell now...
"@

write-host "* Unmounting and saving the wim image"
dismount-windowsimage -save -path $mount -erroraction stop

write-host "* Work is complete and the WIM should be ready to roll!"
