# Razor API Overview and Use

## Compatibility, URL Stability, and Ongoing Support

The Razor API adopts the REST notion that hypertext defines the API, rather
than URL templates or clients with special knowledge of the URL structure.

As developers, we promise good compatibility and support for your client if
you follow the simple rule: use navigation, rather than client-side knowledge
of the URL structure.

To do that, implement any action by starting at `https://razor:8150/api`,
rather than anywhere else in the API namespace.  This document then allows you
to navigate -- much like a web browser can navigate a website -- through the
various query options available to you.

While this document contains some example URL's, and client output examples
also include some, you should make no assumptions that the URLs that your
server uses follow the same structure as the ones in this document.

### Stability Warning

The Razor API is not in a stable state yet. While we try our best to not make
any incompatible changes, we can't guarantee that we won't.  This is
supported, in part, by providing clients with well versioned navigation tools
to discover their desired endpoint, or to cleanly discover that it does not
exist any longer.

Even after we declare the API stable, clients will have to be able to deal
with changes to the API: the URL structure, other than the top level
navigation entry point, is not subject to any assurance that it will stay
as-is.  Use hypertext navigation, and normal HTTP caching, to ensure this does
not burn you.

The one hard-coded URL you can use reliably is `/api`, and the document it
returns is intended to be significantly more stable than any other component
of the API.  This is because it is the root of all navigation, and if we break
that no other compatibility assurances matter. ;)

## How to navigate through the document

The type of objects is indicated with a `spec` attribute. The value of the
attribute is an absolute URL underneath
http://api.puppetlabs.com/razor/v1. These URL's are currently not (yet) backed
by any content, and serve solely as a unique identifier.

Two attributes are commonly used to identify objects: `id` is a fully
qualified URL that can be used as a globally unique reference for that
object, and a `GET` request against that URL will produce a representation
of the object. The `name` attribute is used for a short (human readable)
reference to the object, generally only unique amongst objects of the same
type on the same server.

### `/api` document reference

When you fetch `https://razor:8150/api`, you fetch the top level entry point
for navigating through our command and query facilities.  The structure of
this document is a JSON object with the following keys:

 * `commands`: the commands -- mutating operations -- available on this server
 * `collections`: the collections -- read-only queries -- available on this server

Each of those keys contains a JSON array, with a sequence of JSON objects,
which have the following keys:

 * `name`: a human-readable label.  No stability promises.
 * `rel`: a "spec URL" that indicates the type of contained data.  Use this to
          discover the endpoint that you wish to follow, rather than the `name`.
 * `id`: the URL to follow to get at this content.

This document has a reasonable stability promise: you should be prepared to
ignore additional keys at any level, and to treat the value of those keys as
"unspecified" rather than assuming they will be JSON arrays.

If you follow those simple rules (eg: assume that this documents the minimum
content returned, and ignore everything else), you can have good confidence
that you will not need to change your client.

### `/svc` URLs

The `/svc` namespace is an internal namespace, used for communication with the
iPXE client, the Microkernel, and other internal components of Razor.

This namespace is not enumerated under `/api`, and has no stability promises.
If you use this namespace, be aware that operations are designed specifically
for the needs of our internal components rather than as generic query, and
that we make *NO PROMISES* about stability of these calls, or their content,
even over patch releases.

## Commands

The list of commands that the Razor server supports is returned as part of
a request to `GET /api` in the `commands` array. Clients can identify
commands using the `rel` attribute of each entry in the array, and should
make their POST requests to the URL given in the `url` attribute.

Commands are generally asynchronous and return a status code of 202
Accepted on success. The `url` property of the response generally refers to
an entity that is affected by the command and can be queried to determine
when the command has finished.

### Create new repo

There are three flavors of repositories: ones where Razor unpacks ISO's for
you and serves their contents, ones that are somewhere else (For example,
on a mirror you maintain), and ones where a stub directory is created and
the contents can be entered manually. The first form is created by creating a
repo with the `iso_url` property; the server will download and unpack the
ISO image into its file system:

    {
      "name": "fedora19",
      "iso_url": "file:///tmp/Fedora-19-x86_64-DVD.iso"
      "task": "puppet"
    }

The second form is created by providing a `url` property when you create
the repository; this form is merely a pointer to a resource somewhere and
nothing will be downloaded onto the Razor server:

    {
      "name": "fedora19",
      "url": "http://mirrors.n-ix.net/fedora/linux/releases/19/Fedora/x86_64/os/"
      "task": "noop"
    }

The third form is created by providing a `no-content` property when you
create the repository. This format will create an empty directory in the
repo-store directory where files can be added manually. This is useful
for ISOs which have issues being uncompressed normally due to e.g.
forward references:

    {
      "name": "fedora19",
      "no-content": true
      "task": "noop"
    }

This command must be supplied a default task, which can be overridden at
the policy level. If no task is to be used, reference the stock task
"noop".

### Delete a repo

The `delete-repo` command accepts a single repo name:

    {
      "name": "fedora16"
    }

### Create task

Razor supports both tasks stored in the filesystem and tasks
stored in the database; for development, it is highly recommended that you
store your tasks in the filesystem. Details about that can be found
[on the Wiki](https://github.com/puppetlabs/razor-server/wiki/Writing-tasks)

For production setups, it is usually better to store your tasks in the
database. To create a task, clients post the following to the
`/spec/create_task` URL:

    {
      "name": "redhat6",
      "os": "Red Hat Enterprise Linux",
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

name       | The name of the task; must be unique
os         | The name of the OS; mandatory
description| Human-readable description
boot_seq   | A hash mapping the boot counter or 'default' to a template
templates  | A hash mapping template names to the actual ERB template text

### Create broker

To create a broker, clients post the following to the `create-broker` URL:

    {
      "name": "puppet",
      "configuration": {
         "server": "puppet.example.org",
         "environment": "production"
      },
      "broker_type": "puppet"
    }

The `broker_type` must correspond to a broker that is present on the
`broker_path` set in `config.yaml`.

The permissible settings for the `configuration` hash depend on the broker
type and are declared in the broker type's `configuration.yaml`.

### Delete broker

A broker can be deleted by posting its name to the `/spec/delete_broker`
command:

    {
      "name": "small",
    }

If the broker is used by a policy, the attempt to delete the broker will
fail.

### Update broker configuration

A broker's configuration can be updated using the `update-broker-configuration`
command. This command can set or clear a single key's value. The following
arguments would set the configuration value for key `some_key` to `new_value`:

    {
      "broker": "mybroker",
      "key": "some_key",
      "value": "new_value"
    }

The following arguments would clear the configuration value for key `some_key`:

    {
      "broker": "mybroker",
      "key": "some_key",
      "clear": true
    }

### Create tag

To create a tag, clients post the following to the `/spec/create_tag`
command:

    {
      "name": "small",
      "rule": ["=", ["fact", "processorcount"], "2"]
    }

The `name` of the tag must be unique; the `rule` is a match expression.

### Delete tag

A tag can be deleted by posting its name to the `/spec/delete_tag` command:

    {
      "name": "small",
      "force": true
    }

If the tag is used by a policy, the attempt to delete the tag will fail
unless the optional parameter `force` is set to `true`; in that case the
tag will be removed from all policies that use it and then deleted.

### Update tag

The rule for a tag can be changed by posting the following to the
`/spec/update_tag_rule` command:

    {
      "name": "small",
      "rule": ["<=", ["fact", "processorcount"], "2"],
      "force": true
    }

This will change the rule of the given tag to the new rule. The tag will be
reevaluated against all nodes and each node's tag attribute will be updated
to reflect whether the tag now matches or not, i.e., the tag will be added
to/removed from each node's tag as appropriate.

If the tag is used by any policies, the update will only be performed if
the optional parameter `force` is set to `true`. Otherwise, the command
will return with status code 400.

### Create policy

    {
      "name": "a policy",
      "repo": "some_repo",
      "task": "redhat6",
      "broker": "puppet",
      "hostname": "host${id}.example.com",
      "root_password": "secret",
      "max_count": "20",
      "before"|"after": "other policy",
      "node_metadata": { "key1": "value1", "key2": "value2" },
      "tags": ["existing_tag"]
    }

The overall list of policies is ordered, and policies are considered in that
order. When a new policy is created, the entry `before` or `after` can be
used to put the new policy into the table before or after another
policy. If neither `before` or `after` are specified, the policy is
appended to the policy table.

Tags, brokers, tasks and repos are referenced by their name.

Hostname is a pattern for the host names of the nodes bound to the policy;
eventually you'll be able to use facts and other fun stuff there. For now,
you get to say ${id} and get the node's DB id.

The `max_count` determines how many nodes can be bound at any given point
to this policy at the most. This can either be set to `nil`, indicating
that an unbounded number of nodes can be bound to this policy, or a
positive integer to set an upper bound.

The `node_metadata` allows a policy to apply metadata to a node when it
binds.  This is NON AUTHORITIVE in that it will not replace existing
metadata on the node with the same keys it will only add keys that are
missing.

### Move policy

This command makes it possible to change the order in which policies are
considered when matching against nodes. To put an existing policy into a
different place in the policy table, use the `move-policy` command with a
body like:

    {
      "name": "a policy",
      "before"|"after": "other policy"
    }

This will change the policy table so that `a policy` will appear before or
after the policy `other policy`.

### Enable/disable policy

Policies can be enabled or disabled. Only enabled policies are used when
matching nodes against policies. There are two commands to toggle a
policy's `enabled` flag: `enable-policy` and `disable-policy`, which both
accept the same body, consisting of the name of the policy in question:

    {
      "name": "a policy"
    }

### Modify the max_count for a policy

The command `modify-policy-max-count` makes it possible to manipulate how
many nodes can be bound to a specific policy at the most. The body of the
request should be of the form:

    {
      "name": "a policy"
      "max_count": new-count
    }

The `new-count` can be an integer, which must be larger than the number of
nodes that are currently bound to the policy. Alternatively, the `no_max_count`
argument will make the policy unbounded:

    {
      "name": "a policy"
      "no_max_count": true
    }

### Add/remove tags to/from Policy

You can add or remove tags from policies with `add-policy-tag` and
 `remove-policy-tag` respectively.  In both cases supply the name of a
policy and the name of the tag.  When adding a tag, you can specify an
existing tag, or create a new one by supplying a name and rule for the
new tag:

    {
      "name": "a-policy-name",
      "tag" : "a-tag-name",
      "rule": "new-match-expression" #Only for `add-policy-tag`
    }

### Update policy task

This ensures that a specified policy uses the task this command specifies,
setting the task if necessary. If a node is currently provisioning against the
policy when you run this command, provisioning errors may occur.

    The following shows how to update a policy’s task to a task called “other_task”.

    {
    "node": "node1",
    "policy": "my_policy",
    "task": "other_task"
    }

### Delete policy

Policies can be deleted with the `delete-policy` command.  It accepts the
name of a single policy:

    {
      "name": "my-policy"
    }

Note that this does not affect the `installed` status of a node, and
therefore won't, by itself, cause a node to be bound to another policy upon
reboot.

### Update repo task

This ensures that a specified repo uses the task this command specifies,
setting the task if necessary. If a node is currently provisioning against the
repo when you run this command, provisioning errors may occur.

    The following shows how to update a repo’s task to a task called “other_task”.

    {
    "node": "node1",
    "repo": "my_repo",
    "task": "other_task"
    }

    The following shows how to update a repo’s task to its repo's task.

    {
    "node": "node1",
    "repo": "my_repo",
    "no_task": true
    }

### Create hook

A hook can be created with the `create-hook` command.  It accepts the name
of a single hook, plus the `hook_type` which references existing code
on the Razor server's `hooks` directory, and an optional starting
configuration corresponding to that hook_type:

    {
      "name": "myhook",
      "hook_type": "some_hook",
      "configuration": {"foo": 7, "bar": "rhubarb"}
    }

The code on the server would be contained in the `hooks/some_hook.hook`
directory. More information on hooks can be found in the Hooks README 
(`hooks.md`).

### Update hook configuration

A hook's configuration can be updated using the `update-hook-configuration`
command. This command can set or clear a single key's value. The following
arguments would set the configuration value for key `some_key` to `new_value`:

    {
      "hook": "myhook",
      "key": "some_key",
      "value": "new_value"
    }

The following arguments would clear the configuration value for key `some_key`:

    {
      "hook": "myhook",
      "key": "some_key",
      "clear": true
    }

### Run hook

The `run-hook` command triggers a hook to execute. This is helpful when writing
your own hook scripts in testing their validity. To run the hook which would
occur when the given node boots, use the following arguments:

    {
      "name": "myhook",
      "node": "node1",
      "event": "node-booted"
    }

Note that any of the usual event names can be used for the `event` argument.
See `hooks.md` for a list of these possibilities.

### Delete hook

A single hook can be removed from the database with the `delete-hook`
command. It accepts the name of a single hook:

    {
        "name": "myhook"
    }

The hook will then no longer be triggered for node events and any
existing properties in the hook's `configuration` will be deleted.

### Delete node

A single node can be removed from the database with the `delete-node`
command. It accepts the name of a single node:

    {
      "name": "node17"
    }

Of course, if that node boots again at some point, it will be automatically
recreated.

### Reinstall node

This command removes a node's association with any policy and clears its
`installed` flag; once the node reboots, it will boot back into the
Microkernel and go through discovery, tag matching and possibly be bound to
another policy. This command does not change its metadata or facts. Specify
which node to unbind by sending the node's name in the body of the request:

    {
      "name": "node17"
    }

The `same_policy` flag can be used to skip the microkernel boot and policy
binding stage, installing the same task/repo/policy again. This is most helpful
when developing a custom task.

    {
      "name": "node17",
      "same_policy: true
    }

### Set node IPMI credentials

Razor can store IPMI credentials on a per-node basis.  These are the hostname
(or IP address), the username, and the password to use when contacting the
BMC/LOM/IPMI lan or lanplus service to check or update power state and other
node data.

This is an atomic operation: all three data items are set or reset in a single
operation.  Partial updates must be handled client-side.  This eliminates
conflicting update and partial update combination surprises for users.

The structure of a request is:

    {
      "name": "node17",
      "ipmi_hostname": "bmc17.example.com",
      "ipmi_username": null,
      "ipmi_password": "sekretskwirrl"
    }

The various IPMI fields can be null (representing no value, or the NULL
username/password as defined by IPMI), and if omitted are implicitly set to
the NULL value.

You *must* provide an IPMI hostname if you provide either a username or
password, since we only support remote, not local, communication with the
IPMI target.

### Reboot node

Razor can request a node reboot through IPMI, if the node has IPMI credentials
associated.  This only supports hard power cycle reboots.

This is applied in the background, and will run as soon as available execution
slots are available for the task -- IPMI communication has some generous
internal rate limits to prevent it overwhelming the network or host server.

This background process is persistent: if you restart the Razor server before
the command is executed, it will remain in the queue and the operation will
take place after the server restarts.  There is no time limit on this at
this time.

Multiple commands can be queued, and they will be processed sequentially, with
no limitation on how frequently a node can be rebooted.

If the IPMI request fails (that is: ipmitool reports it is unable to
communicate with the node) the request will be retried.  No detection of
actual results is included, though, so you may not know if the command is
delivered and fails to reboot the system.

This is not integrated with the IPMI power state monitoring, and you may not
see power transitions in the record, or through the node object if polling.

The format of the command is:

    {
      "name": "node1",
    }

The `node` field is the name of the node to operate on.

The RBAC pattern for this command is: `reboot-node:${node}`


### Set node desired power state

In addition to monitoring power, Razor can enforce node power state.
This command allows a desired power state to be set for a node, and if the
node is observed to be in a different power state an IPMI command will be
issued to change to the desired state.

The format of the command is:

    {
      "name": "node1234",
      "to":   "on"|"off"|null
    }

The `name` field identifies the node to change the setting on.

The `to` field contains the desired power state to set.  Valid values are
`on`, `off`, or `null` (the JSON NULL/nil value), which reflect "power on",
"power off", and "do not enforce power state" respectively.

Power state is enforced every time it is observed; by default this happens
on a scheduled basis in the background every few minutes.


### Modify node metadata

Node metadata is similar to a nodes facts except metadata is what the
administrators tell Razor about the node rather than what the node tells
Razor about itself.

Metadata is a collection of key => value pairs (like facts).  Use the
`modify-node-metadata` command to add/update, remove or clear a node's
metadata. The request should look like:

    {
        "node": "node1",
        "update": {                         # Add or update these keys
            "key1": "value1",
            "key2": "value2",
            ...
        }
        "remove": [ "key3", "key4", ... ],  # Remove these keys
        "no_replace": true                  # Do not replace keys on
                                            # update. Only add new keys
    }

or

    {
        "node": "node1",
        "clear": true                       # Clear all metadata
    }

As above, multiple update and/or removes can be done in the one command,
however, clear can only be done on its own (it doesnt make sense to
update some details and then clear everything).  An error will also be
returned if an attempt is made to update and remove the same key.

Note that metadata values can also be structured data specified as native
JSON or as a valid JSON string.  E.g:

    {
        "node": "node1",
        "update": {
            "key1": [ "list", "of", "values" ],
        }
    }

### Update node metadata

The `update-node-metadata` command is a shortcut to `modify-node-metadata`
that allows for updating single keys on the command line or with a GET
request with a simple data structure that looks like.

    {
        "node"      : "mode1",
        "key"       : "my_key",
        "value"     : "my_val",
        "no_replace": true       #Optional. Will not replace existing keys
    }

Note that metadata values can also be structured data specified as native
JSON or as a valid JSON string.  E.g:

    {
        "node"      : "mode1",
        "key"       : "my_key",
        "value"     : "[ "list", "of", "values" ]",
    }

### Remove Node Metadata

The `remove-node-metadata` command is a shortcut to `modify-node-metadata`
that allows for removing a single key OR all keys only on the command
like or with a GET request with a simple datastructure that looks like:

    {
        "node" : "node1",
        "key"  : "my_key",
    }

or

    {
        "node" : "node1",
        "all"  : true,     # Removes all keys
    }

### Set Node Hardware Info

When hardware is changed in a node, such as a network card being replaced,
the Razor server may need to be informed so that it can correctly match
the new hardware with the existing node definition.

This command enables replacing the existing hardware info data with new
data, making it possible to update the existing node record prior to
booting the new node on the network. For example, to update `node172`
with new hardware information:

    {
        "node": "node172",
        "hw_info": {
          "net0":   "78:31:c1:be:c8:00",
          "net1":   "72:00:01:f2:13:f0",
          "net2":   "72:00:01:f2:13:f1",
          "serial": "xxxxxxxxxxx",
          "asset":  "Asset-1234567890",
          "uuid":   "Not Settable"
        }
    }


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
        "spec": "https://localhost:8150/spec/object/tag",
        "id": "https://localhost:8150/api/collections/objects/14",
        "name": "virtual",
        "rule": [ "=", [ "fact", "is_virtual" ], true ]
      },
      {
        "spec": "https://localhost:8150/spec/object/tag",
        "id": "https://localhost:8150/api/collections/objects/27",
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

### Querying the node collection

Nodes can be queried by the following items

* `hostname`: a regular expression to match against hostnames; this
  includes using part of a hostname, e.g., `hostname=foo` to get all nodes
  whose hostname includes `foo`
* the fields that are stored in the `hw_info` of a node, namely `mac`,
  `serial`, `asset`, and `uuid`

For example the UUID could be queried to return the associated node

    /api/collections/nodes?uuid=9ad1e079-b9e3-347c-8b13-9b42cbf53a14'

    {
      "items": [
        {
            "id": "https://razor.example.com:8150/api/collections/nodes/node14",
            "name": "node14",
            "spec": "http://api.puppetlabs.com/razor/v1/collections/nodes/member"
        }],
      "spec": "http://api.puppetlabs.com/razor/v1/collections/nodes"
    }

## Other things

### The default boostrap iPXE file

A GET request to `/api/microkernel/bootstrap` will return an iPXE script
that can be used to bootstrap nodes that have just PXE booted (it
culminates in chain loading from the Razor server)

The URL accepts the parameter `nic_max` which should be set to the maximum
number of network interfaces that respond to DHCP on any given machine. It
defaults to 4.

If this request to generate the bootstrap file occurs over HTTPS, the
`http_port` parameter must be supplied. This is the HTTP (non-SSL/TLS) port
number that booted nodes will use to communicate with the Razor server.

A full request to render a bootstrap file might look like this, where 8150 is
the port used for HTTP communication:
`curl -k "https://user:password@razor-server:8151/api/microkernel/bootstrap?nic_max=4&http_port=8150"`

