# API Overview

Some boilerplate on how URL's in this doc are only as examples, how we only
support JSON, ...

## Commands

The list of commands that the Razor server supports is returned as part of
a request to `GET /api` in the `commands` array. Clients can identify
commands using the `rel` attribute of each entry in the array, and should
make their POST requests to the URL given in the `url` attribute.

Commands are generally asynchronous and return a status code of 202
Accepted on success. The `url` property of the response generally refers to
an entity that is affected by the command and can be queried to determine
when the command has finished.

### Create new image

TODO

### Create installer

To create an installer, clients post the following to the
`/spec/create_installer` URL:

    {
      "name": "redhat6",
      "os": "Red Hat Enterprise Linux",
      "os_version": "6",
      "description": "A basic installer for RHEL6",
      "boot_seq": {
        "1": "boot_install",
        "default": "boot_local"
      }
      "templates": {
        "boot_install": " ... ERB template for an ipxe boot file ...",
        "installer": " ... another ERB template ..."
      }
    }

The possible properties in the request are:

name       | The name of the installer; must be unique
os         | The name of the OS; mandatory
os_version | The version of the operating system
description| Human-readable description
boot_seq   | A hash mapping the boot counter or 'default' to a template
templates  | A hash mapping template names to the actual ERB template text
