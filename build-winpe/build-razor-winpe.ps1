# -*- powershell -*-
# During development, this was run locally with:
# powershell -executionpolicy bypass -file build-razor-winpe.ps1
#
# For release we should sign the script, I guess?

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
re-run this script yourself.  Sorry.
"@
    exit 1
}


# Basic location stuff...
$cwd    = get-currentdirectory
$output = join-path $cwd "razor-winpe"
$mount  = join-path $cwd "razor-winpe-mount"


########################################################################
# Some "constants" that might have to change to accomodate different
# versions of of the WinPE building tools or whatever.  These are
# factored out mostly for my convenience, honestly.

# Default install root for the ADK; since the installer database
# does not contain custom paths, if any, this was installed to,
# we are stuck with just defaulting and failing.
$adk = @([Environment]::GetFolderPath('ProgramFilesX86'),
         [Environment]::GetFolderPath('ProgramFiles')) |
           % { join-path $_ 'Windows Kits\8.0\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64' } |
           ? { test-path  $_ } |
           select-object -First 1

# Path to the clean WinPE WIM file.
$wim = join-path $adk "en-us\winpe.wim"

# Root for the CAB files for optional features.
$packages = join-path $adk "WinPE_OCs"


########################################################################
# ...and these are "constants" that are calculated from the above.
write-host "Make sure our working and output directories exist."
if (test-path -path $output) {
    write-error "Output path $output already exists, aborting!"
    exit 1
} else {
    new-item -type directory $output
}

if (-not(test-path -path $mount)) {
    new-item -type directory $mount
}


write-host "Copy the clean ADK WinPE image into our output area."
copy-item $wim $output
# update our wim location...
$wim = join-path $output "winpe.wim"



write-host "importing dism module"
import-module dism

write-host "mounting the wim image"
mount-windowsimage -imagepath $wim -index 1 -path $mount -erroraction stop

write-host "adding powershell, and dependencies, to the image"
# This order is documented in http://technet.microsoft.com/library/hh824926.aspx
# I guess you can't change it safely, so respect that.
@('WinPE-WMI', 'WinPE-NetFX4', 'WinPE-Scripting', 'WinPE-PowerShell3') | foreach {
    write-host "installing $_ to image"
    # there must be a way to do this without a temporary variable
    $pkg = join-path $packages "$_.cab"
    add-windowspackage -packagepath $pkg -path $mount
}

write-host "writing startup PowerShell script"
$file   = join-path $mount "razor-client.ps1"
$client = join-path $cwd "razor-client.ps1"
copy-item $client $file

write-host "writing Windows\System32\startnet.cmd script"
$file = join-path $mount "Windows\System32\startnet.cmd"
set-content $file @'
@echo off
echo starting wpeinit to detect and boot network hardware
wpeinit
echo starting the razor client
powershell -executionpolicy bypass -noninteractive -file %SYSTEMDRIVE%\razor-client.ps1
echo dropping to a command shell now...
'@

write-host "unmounting and saving the wim image"
dismount-windowsimage -save -path $mount -erroraction stop

write-host "work is complete and the WIM should be ready to roll!"
