# Hooks

Hooks provide a way to run arbitrary scripts when certain events occur during
the operation of the Razor server. The behavior and structure of a hook are
defined by a *hook type*.

The two primary components for hooks are:
- *Configuration*: This is a keystore for storing data on a hook. These have an
  initial value and can be updated by hook scripts.
- *Event Scripts*: These are scripts that run when a specified event occurs.
  Event scripts must be named according to the handled event.

## File layout for a hook type

Similar to brokers and tasks, hook types are defined through a `.hook`
directory and optional event scripts within that directory:

    hooks/
      some.hook/
        configuration.yaml
        node-bind-policy
        node-unbind-policy
        ...

## Creating hook objects

The `create-hook` command is used to create a hook object from a hook type:

    > razor create-hook --name myhook --hook-type some_hook \
        --configuration foo=7 --configuration bar=rhubarb

The hook object created by this command will track changes to the hook's
configuration over time.

The `delete-hook` command is used to remove a hook.

If a hook's configuration needs to change, it must be deleted then recreated
with the updated configuration.

## Hook Configuration

Hook scripts can use the hook object's `configuration`

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
the hook's `configuration.yaml` and the properties set by the current
values of the hook object's `configuration`. With the `create-hook` command
above, the input JSON would be:

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
indicate changes that should be made to the hook's `configuration`. The
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

### Available events

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

## Sample hook

Here is an example of a basic hook that will count the number of times Razor
registers a node. Let's name the hook `counter` and create a corresponding
directory for the hook type, `counter.hook`, inside the `hooks` directory. We
can store the current count as a configuration entry with the key `count`. Thus
the `configuration.yaml` file might look like this:

    ---
    count:
      description: "The current value of the counter"
      default: 0

We want to write a script that runs whenever a node gets bound to
a policy, so we make a file called `node-bound-to-policy` and place it in the
`counter.hook` folder. We can then write this script, which reads in the
current configuration value, increments it, then returns some JSON to update
the configuration on the hook object:

    #! /bin/bash

    json=$(< /dev/stdin)

    name=$(jq '.hook.name' <<< $json)
    value=$(( $(jq '.hook.config.count' <<< $json) + 1 ))

    cat <<EOF
    {
      "hook": {
        "configuration": {
          "count": $value
        }
      },
      "metadata": {
        $name: $value
      }
    }
    EOF

That completes the hook type. Next, we'll create the hook object which will
store the configuration via:

    razor create-hook --name counter --hook-type counter

Since the configuration is absent from this creation call, the default value
of 0 in `configuration.yaml` is used. Alternatively, this could be set using
`--configuration count=0` or `--c count=0`.

The hook is now ready to go. You can query the existing hooks in a system via
`razor hooks`. To query the current value of the hook's configuration,
`razor hooks counter` will show `count` initially set to 0. When a node gets
bound to a policy, the `node-bound-to-policy` script will be triggered,
yielding a new configuration value of 1.
