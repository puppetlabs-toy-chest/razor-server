# Task notes for Windows 2012 R2

## Pre-install Steps

Follow same instructions for all other Windows tasks:

- Build winpe.wim image using the `build-razor-winpe.ps1` script.
- Copy winpe.wim to the server.
- Make sure winpe.wim is readable by the Razor service.
- Install/configure Samba share.

## Node Metadata

- 'productkey' (optional) - This will be substituted into the unattended.xml
  for the product key used during installation.
  - Default: The evaluation/trial key provided by Microsoft