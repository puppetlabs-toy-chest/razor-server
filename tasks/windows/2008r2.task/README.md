# Task notes for Windows 2008 R2

## Install Prerequisites

- Machine must be running Windows 2008 R2.
- Windows Management Framework (WMF) version 4.0 is installed.
-- Windows Update service must be running in order to install this.
- Windows Assessment and Deployment Kit (Windows ADK) version 8.0 or 8.1 is 
  installed.

## Pre-install Steps

Follow same instructions for all other Windows tasks:

- Download `build-winpe` folder from Razor server.
- Build winpe.wim image using the `build-razor-winpe.ps1` script.
- Copy winpe.wim to the server.
- Make sure winpe.wim is readable by the Razor service.
- Install/configure Samba share.

## Node Metadata

- 'productkey' (optional) - This is the product key which will be substituted
  into the unattended.xml file inside the UserData => ProductKey tag.
  - Default: The product key provided as an evaluation key for this Windows
    version.
- 'timezone' (optional) - This is the string corresponding to the timezone for
  the node.
  - Default: Pacific Standard Time
- 'root_password' (optional) - This is an override for the root_password that
  exists on the node when it binds to a policy. If this is provided, it will be
  used for the node's root password.
- 'hostname' (optional) - This is an override for the computer name that
  exists on the node when it binds to a policy. If this is provided, it will be
  used for the node's computer name. (NOTE: This should not include the domain.)