# API Overview

Some boilerplate on how URL's in this doc are only as examples, how we only
support JSON, ...

## Conventions

The type of objects is indicated with a `spec` attribute. The value of the
attribute is an absolute URL underneath
http://api.puppetlabs.com/razor/v1. These URL's are currently not backed by
any content, and serve solely as a unique identifier.

Two attributes are commonly used to identify objects: `id` is a fully
qualified URL that can be used as a globally unique reference for that
object, and a `GET` request against that URL will produce a representation
of the object. The `name` attribute is used for a short (human readable)
reference to the object, generally only unique amongst objects of the same
type on the same server.

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

Load an image into the server

    {
      "name": "fedora19",
      "image-url": "file:///tmp/Fedora-19-x86_64-DVD.iso"
    }

Both name and image-url must be supplied

### Delete an image

The `delete-image` command accepts a single image name:

    {
      "name": "fedora16"
    }

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

### Create broker

To create a broker, clients post the following to the `create-broker` URL:

    {
      "name": "puppet",
      "configuration": { "server": "puppet.example.org", "version": "3.0.0" },
      "broker-type": "puppet"
    }

The `broker-type` must correspond to a broker that is present on the
`broker_path` set in `config.yaml`.

The permissible settings for the `configuration` hash depend on the broker
type and are declared in the broker type's `configuration.yaml`.

### Create tag

To create a tag, clients post the following to the `/spec/create_tag`
command:

    {
      "name": "small",
      "rule": ["=", ["facts", "f1"], "42"]
    }

The `name` of the tag must be unique; the `rule` is a match expression.

### Create policy

    {
      "name": "a policy",
      "image": { "name": "some_image" },
      "installer": { "name": "redhat6" },
      "broker": { "name": "puppet" },
      "hostname": "host${id}.example.com",
      "root_password": "secret",
      "max_count": "20",
      "line_number": "100"
      "tags": [{ "name": "existing_tag"},
               { "name": "new_tag", "rule": ["=", "dollar", "dollar"]}]
    }

Policies are matched in the order of ascending line numbers.

Tags, brokers, installers and images are referenced by their name. Tags can
also be created by providing a rule; if a tag with that name already
exists, the rule must be equal to the rule of the existing tag.

Hostname is a pattern for the host names of the nodes bound to the policy;
eventually you'll be able to use facts and other fun stuff there. For now,
you get to say ${id} and get the node's DB id.

### Delete node

A single node can be removed from the database with the `delete-node`
command. It accepts the name of a single node:

    {
      'name': 'node17'
    }

Of course, if that node boots again at some point, it will be automatically
recreated.

## Collections

Along with the list of supported commands, a `GET /api` request returns a list
of supported collections in the `collections` array. Each entry contains at
minimum `url`, `spec`, and `name` keys, which correspond respectively to the
endpoint through which the collection can be retrieved (via `GET`), the 'type'
of collection, and a human-readable name for the collection.

A `GET` request to a collection endpoint will yield a list of JSON objects,
each of which has at minimum the following fields:

id   | a URL that uniquely identifies the object
spec | a URL that identifies the type of the object
name | a human-readable name for the object

Different types of objects may specify other properties by defining additional
key-value pairs. For example, here is a sample tag listing:

    [
      {
        "spec": "http://localhost:8080/spec/object/tag",
        "id": "http://localhost:8080/api/collections/objects/14",
        "name": "virtual",
        "rule": [ "=", [ "fact", "is_virtual" ], true ]
      },
      {
        "spec": "http://localhost:8080/spec/object/tag",
        "id": "http://localhost:8080/api/collections/objects/27",
        "name": "group 4",
        "rule": [
          "in", [ "fact", "dhcp_mac" ],
          "79-A8-C3-39-E4-BA",
          "6C-35-FE-B7-BD-2D",
          "F9-92-DF-E0-26-5D"
        ]
      }
    ]

In addition, references to other resources are represented either as an array
of, in the case of a one- or many-to-many relationship, or single, for a one-
to-one relationship, JSON objects with the following fields:

url    | a URL that uniquely identifies the object
obj_id | a short numeric identifier
name   | a human-readable name for the object

If the reference object is in an array, the `obj_id` field serves as a unique
identifier within the array.

## Other things

### The default boostrap iPXE file

A GET request to `/api/microkernel/bootstrap` will return an iPXE script
that can be used to bootstrap nodes that have just PXE booted (it
culminates in chain loading from the Razor server)

The URL accepts the parameter `nic_max` which should be set to the maximum
number of network interfaces that respond to DHCP on any given machine. It
defaults to 4.
