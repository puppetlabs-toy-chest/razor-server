# Razor Server Release Notes

## 0.15.0 - 2014-??-??

+ incompatible changes
  + the way that tasks and templates are stored on disk has changed.
    The metadata file is changed from `tasks/{name}.yaml` to
    `tasks/{name}.task/metadata.yaml`. The search path for templates has
    changed from:
    1. `tasks/{name}/{os_version}`
    2. `tasks/{name}`
    3. `tasks/{base_task}/{os_version}` (if inheritance was used)
    4. `tasks/{base_task}` (if inheritance was used)
      * [Any other base tasks are searched here recursively]
    5. `tasks/common`
    It is now:
    1. `tasks/{name}.task`
    2. `tasks/{base_task}.task` (if inheritance was used)
      * [Any other base tasks are searched here recursively]
    3. `tasks/common`
    For a more complete guide to migrating, see
    [This migration page](http://links.puppetlabs.com/razor-migration-task-revamp)

## 0.13.0 - 2014-01-21

+ 'recipes' (neé installers) are now called 'tasks', as the word recipes is
  prominently used by Chef and would just lead to confusion
+ IPMI support now allows rebooting nodes, and setting a desired power stat
  ('on' or 'off') which the server will enforce

### Public API changes

+ incompatible changes
  + the way how policy ordering is handled has changed: instead of exposing
    a `rule_number` that has to be set in `create-policy`, new policies are
    now by default appended to the policy table. Their position can be
    controlled with the `before` and `after` parameters to the
    `create-policy` command. The `rule_number` is not part of the view of a
    policy anymore either. To determine the order of policies, they need to
    be listed with `/api/collections/policies` which returns all policies
    in the order in which they are matched against a node
+ the `node` object view has changed:
  - the `node["state"]["power"]` field is removed.
  - the `node["power"]` object is added with the fields:
    * `"desired_power_state"` reflecting the configured desired power state for the node
    * `"last_known_power_state"` reflecting the last observed power state
    * `"last-power_state_update_at"` reflecting the point in time that power state observation was taken.
  - it is important to note that this is not a real-time power state, but a
    scheduled observation; do not assume that the last known state reflects
    current reality.
+ new commands
  + `move-policy` to move a policy before/after another policy
  + `reboot-node` to reboot a node via IPMI (soft and hard)
  + `set-node-desired-power-state` to indicate whether a node should be
    `on` or `off` and have Razor enforce that
  + `delete-broker` makes it possible to delete existing brokers
+ policies can seed the metadata for nodes; this is set via the
`node_metadata` parameter of the `create-policy` command (Chris Portmann)
+ the details for a broker now have a `policies` collection which shows the
  policies using that broker
+ the new puppet-pe broker allows seamless integration with the simplified
  installation in a forthcoming PE release

## 0.12.0 - 2014-01-03

+ the server's management API underneath `/api` can now be protected with
  username/password. See the [authentication page](https://github.com/puppetlabs/razor-server/wiki/Securing-the-server) on the Wiki for details
+ IPMI support (read-only in this release)
+ "installers" are now called "recipes" as they will, in the future, be
  able to do more than just install operating systems
+ nodes now carry metadata, a list of key/value pairs. Metadata works
  similar to facts, except that it is manipulated through the public API,
  and can be used in tag rules. Nodes can also store metadata values during
  installation
+ nodes now have an explicit `installed` state which recipes have to set by
  calling `stage_done_url("finished")`
+ a brand new chef broker [contributed by Egle Sigler]

### Public API changes

+ incompatible changes
  + collections now return an object instead of an array; the actual
    entries for the collection are in the `1tems` property of that object
  + renaming of `installers` to `recipes`
+ better navigation
  + tags now have subcollections for the nodes and policies that use them
  + policies have a subcollection for the nodes that are bound to them
  + the nodes collection can now be searched by hostname (with a regexp)
    and by the various hw_info fields (mac, serial, uuid, ...)
  + there is no a real `recipes` collection that lists all known recipes
    (file- and database-backed ones)
+ new commands
  + `set-node-ipmi-credentials` to set up the details of a node's BMC/IPMI
    interface
  + `modify-node-metadata`, `update-node-metadata`, and
    `remove_node_metadata` commands to manipulate a node's metadata
  + `modify-policy-max-count` to manipulate the quota for a policy
  + `reinstall-node` to cause a node to go through the policy table again
    (used to be called `unbind-node`)
  + `delete_policy` to delete a policy; nodes that were bound to that
    policy and had finished installing will not be reinstalled
  + `policy_add_tag` and `policy_remove_tag` to associate/disassociate tags
    with/from a given policy
+ nodes now report a status, including whether they are installed, and at
  what stage the installer for a possibly boubd policy is. If the node has
  IPMI credentials, the current power state is also reported

### SVC (node/server) API
+ add `store_metadata_url` helper

### Tag language
+ support a `tag` function that evaluates another tag so that existing tags
  can be reused on rules
+ support a `metadata` function that retrieves values from the node's metadata
+ support a `state` function. Currently only the `installed` state of a
  node can be queried
+ add a boolean `not` operator

### Other
+ `razor-admin` now has a `check-migrations` command which checks if the
   database schema is up to date or not

## 0.11.0 - 2013-11-26

### Public API changes
+ include the installer and broker in the policy detail
+ include the name of the base installer in the installer details
+ new commands enable-policy and disable-policy
+ new commands delete-tag and update-tag-rule

### Installers
+ add installer for ESXi 5.5
+ add installer for Windows 8; details are on the
  [Wiki](https://github.com/puppetlabs/razor-server/wiki/Installing-windows)
+ Debian
  + support the new Debian 7.2 multiarch netboot CD, which includes and
  i386 and an amd64 kernel
+ RHEL
  + properly set the BOOTIF argument; before kickstart could fail if a
    machine had multiple NICs because of this
  + use `/etc/rc.d/rc.local`, not `/etc/rc.local` in the post install
    script; the latter is simply a symlink and making changes to that will
    not be seen by the init scripts
+ Ubuntu
  + Improved Precise (12.04 LTS) installer

### Node/server API changes
+ the `broker_install_url` helper now fetches the broker install script;
  the stock installers now run the broker install script
+ the `file_url` helper now supports fetching raw files, not just
  interpolated templates
+ the `/svc/nodeid` endpoint makes it possible for nodes to look up their
  Razor-internal node id from their hardware information

### Configuration
+ validate various aspects of the server configuration on startup
+ updated `facts.blacklist` in `config.yaml.sample`
+ new setting `match_nodes_on` to select which hardware attributes to
  match on when identifying a node. Defaults to `mac`

### Other
+ support repos that are merely references to content hosted somewhere else
  in addition to repos created by importing an ISO
+ update to Sinatra 1.4.4; this fixes an issue where ipxe would take a
  very long time downloading kernels and initrd's
+ all logging goes through Torquebox's logging subsystem now. See
  [the logging docs](https://github.com/puppetlabs/razor-server/blob/master/doc/logging.md) for details
+ upgrade to Torquebox 3.0.1 and jRuby 1.7.8
+ lots of bug fixes and minor improvements

## 0.10.0 - 2013-09-18

First release of the rewrite. See
[github](https://github.com/puppetlabs/razor-server) for details about the
new code base and for installation instructions.
