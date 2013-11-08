@echo off
echo starting wpeinit to detect and boot network hardware
wpeinit
echo disbale firewall
wpeutil DisableFirewall
echo starting the razor client
powershell -executionpolicy bypass -noninteractive -file %SYSTEMDRIVE%\Razor\razor-client.ps1
echo dropping to a command shell now...
