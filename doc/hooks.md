# Hooks

Hooks provide a way to be notified of certain events during the operation
of the Razor server; the behavior of a hook is defined by a *hook
type*.

## File layout for a hook type

Similar to brokers and tasks, hook types are defined through a `.hook`
directory and files within that directory:

    hooks/
      some.hook/
        configuration.yaml
        node-bind-policy
        node-unbind-policy
        ...

The hook type specifies the configuration data that it accepts in
`configuration.yaml`; that file must define a hash:

    foo:
      description: "Explain what foo is for"
      default: 0
    bar:
      description "Explain what bar is for"
      default: "Barbara"
    ...

For each event that the hook type handles, it must contain a script with
the event's name; that script must be executable by the Razor server. All
hook scripts for a certain event are run (in an indeterminate order) when
that event occurs.

## Creating hooks

The `create-hook` command is used to create a hook from a hook type:

    > razor create-hook --name myhook --hook-type some_hook \
        --configuration foo=7 --configuration bar=rhubarb

Similarly, the `delete-hook` command is used to remove a hook.

## Event scripts

The general protocol is that hook event scripts receive a JSON object on
their stdin, and may return a result by printing a JSON object to their
stdout. The properties of the input object vary by event, but they always
contain a 'hook' property:

    {
      "hook": {
        "name": hook name,
        "configuration": ... user-defined object ...
      }
    }

The `configuration` object is initialized from the Hash described in
the hook's `configuration.yaml` and the properties set by the 
`create-hook` command. With the `create-hook` command above, this 
would result in:

    {
      "hook": {
        "name": "myhook",
        "configuration": {
          "foo": 7,
          "bar": "rhubarb"
        }
      }
    }

The script may return data by producing a JSON object on its stdout to
indicate changes that should be made to the hook's `configuration`; the
updated `configuration` will be used on subsequent invocations of any 
event for that hook. The output must indicate which properties to 
update, and which ones to remove:

    {
      "hook": {
        "configuration": {
          "update": {
            "foo": 8
          },
          "remove": [ "frob" ]
        }
      }
    }


The Razor server makes sure that invocations of hook scripts are
serialized; for any hook, events are processed one-by-one to make it
possible to provide transactional safety around the changes any event
script might make.

### Node events

Most events are directly related to a node. The JSON input to the event
script will have a `node` property which contains the representation of the
node in the same format as the API produces for node details.

The JSON output of the event script can modify the node metadata:

    {
      "node": {
        "metadata": {
          "update": {
            "foo": 8
          },
          "remove": [ "frob" ]
        }
      }
    }

### Error handling

The hook script must exit with exit code 0 if it succeeds; any other exit
code is considered a failure of the script. Whether the failure of a script
has any other effects depends on the event. A failed execution can still
make updates to the hook and node objects by printing to stdout in the same
way as a successful execution.

To report error details, the script should produce a JSON object with an
`error` property on its stdout in addition to exiting with a non-zero exit
code. If the script exits with exit code 0 the `error` property will still
be recorded, but the event's severity will not be an 'error'. The `error`
property should itself contain an object whose `message` property is a
human-readable message; additional properties can be set. Example:

    {
      "error": {
        "message": "connection refused by frobnicate.example.com",
        "port": 2345,
        ...
      }
    }


## Available events

* `node-registered`: triggered after a node has been registered, i.e. after
  its facts have been set for the first time by the Microkernel.
* `node-bound-to-policy`: triggered after a node has been bound to a policy. The
  script input contains a `policy` property with the details of the
  policy that has been bound to the node.
* `node-unbound-from-policy`: triggered after a node has been marked as uninstalled
  by the `reinstall-node` command and thus been returned to the set of
  nodes available for installation.
* `node-deleted`: triggered after a node has been deleted.
* `node-booted`: triggered every time a node boots via iPXE.
* `node-facts-changed`: triggered whenever a node changes its facts.
* `node-install-finished`: triggered when a policy finishes its last step.


## Sample input

The input to the hook script will be in JSON, containing a structure like below:

{
  "hook": {
    "name": "counter",
    "configuration": {
      "value": 0
    }
  },
  "node": {
    "name": "node10",
    "hw_info": {
      "mac": [ "52-54-00-30-8e-45" ],
      "serial": "watz0815",
      "uuid": "ea7c46f8-615f-234f-c1a4-20f0d3edac3d"
    },
    "dhcp_mac": "52-54-00-30-8e-45",
    "tags": ["compute", "anything", "any", "new"],
    "facts": {
      "memorysize_mb": "995.05",
      "myfact": "0815",
      "facterversion": "2.0.1",
      "architecture": "x86_64",
      "hardwaremodel": "x86_64",
      "processor0": "QEMU Virtual CPU version 1.6.2",
      "processorcount": "1",
      "ipaddress": "192.168.100.196",
      "hardwareisa": "x86_64",
      "netmask": "255.255.255.0",
      "uniqueid": "007f0100",
      "physicalprocessorcount": "1",
      "virtual": "kvm",
      "is_virtual": "true",
      "interfaces": "eth0,lo",
      "ipaddress_eth0": "192.168.100.196",
      "macaddress_eth0": "52:54:00:30:8e:45",
      "netmask_eth0": "255.255.255.0",
      "ipaddress_lo": "127.0.0.1",
      "netmask_lo": "255.0.0.0",
      "network_eth0": "192.168.100.0",
      "network_lo": "127.0.0.0",
      "macaddress": "52:54:00:30:8e:45",
      "blockdevice_vda_size": 4294967296,
      "blockdevice_vda_vendor": "0x1af4",
      "blockdevices": "vda",
      "bios_vendor": "Watzmann Ops",
      "bios_version": "08.15",
      "bios_release_date": "01/01/2011",
      "manufacturer": "Watzmann BIOS",
      "productname": "Bochs",
      "serialnumber": "WATZ0815",
      "uuid": "EA7C46F8-615F-234F-C1A4-20F0D3EDAC3D",
      "type": "Other"
    },
    "state": {
      "installed": false
    },
    "hostname": "client-l.watzmann.net",
    "root_password": "secret",
    "last_checkin": "2014-05-21T03:45:47+02:00"
  },
  "policy": {
    "name": "client-l",
    "repo": "centos-6.4",
    "task": "ubuntu",
    "broker": "noop",
    "enabled": true,
    "hostname_pattern": "client-l.watzmann.net",
    "root_password": "secret",
    "tags": ["client-l"],
    "nodes": {
      "count": 0
    }
  }
}

