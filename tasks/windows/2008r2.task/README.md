# Task notes for Windows 2008 R2

## Install Prerequisites

- Machine must be running Windows 2008 R2.
- Windows Management Framework (WMF) version 4.0 is installed.
-- Windows Update service must be running in order to install this.
- Windows Assessment and Deployment Kit (Windows ADK) version 8.0 or 8.1 is 
  installed.
- Download `build-winpe` folder from Razor server.

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