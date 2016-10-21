# Razor Server Release Notes

## 1.5.0 - 2016-10-20

### API changes

+ BUGFIX: The `set-node-hw-info` command now works if the 
  `match_nodes_on` Razor config includes `mac` (default).`
+ BUGFIX: The `update-node-metadata` and `modify-node-metadata` commands
  now throw the intended errors if `no_replace` is supplied and the key
  exists. For the latter command, you may supply the new argument
  `force` to achieve the old functionality of simply skipping the
  replacing key.
+ NEW: Added `update-policy-node-metadata` command to facilitate
  changing the metadata that gets added to a node when it binds to a
  policy.
+ NEW: Added `update-policy-repo` command to facilitate changing
  the repo associated with a policy without needing to manually update
  the repo's contents or delete the policy.
+ NEW: Added `update-policy-broker` command to facilitate
  migrating the broker that a policy uses.
+ IMPROVEMENT: The `set-node-hw-info` command can now accept `mac` as an
  argument.
  
### Task changes

+ NEW: Added Fedora 23 task.

### Broker changes

+ RENAME: The `puppet` broker, which works for Puppet 3, has been
  renamed to `legacy-puppet`. Use the `update-policy-broker` command to
  migrate existing policies that must still use the old `puppet` broker.
+ NEW: The new `puppet` broker will work for Puppet 4.

### Other

+ IMPROVEMENT: Nodes will now store all `hw_info`, not just the values
  used for matching to nodes in the database.
+ BUGFIX: The `puppet-pe` broker for Windows now works properly for
  non-English 64-bit Windows ISO files.
+ BUGFIX: The windows tasks now utilize an optional `win_language`
  configuration in a node's metadata which allows users to install ISOs
  in languages other than English.
+ BUGFIX: Fixed the deletion of repos when the Razor server is running
  on Ubuntu.
+ IMPROVEMENT: The microkernel now works with non-string `is_virtual`
  fact.
+ IMPROVEMENT: The `puppet` and `puppet-pe` brokers will now attempt to
  run `ntpdate` if the `ntpdate_server` config is set.

## 1.4.0 - 2016-07-06

### API changes

+ IMPROVEMENT: Pathing is now consistent with the All-In-One (AIO) agent format.
  Packaging will move these files automatically. These are the included pathing
  changes:
  - `/etc/razor/config.yaml` to `/etc/puppetlabs/razor-server/config.yaml`
  - `/etc/razor/shiro.ini` to `/etc/puppetlabs/razor-server/shiro.ini`
  - `/var/log/razor-server/server.log` to `/var/log/puppetlabs/razor-server/server.log`
  - `hooks`, `brokers`, and `tasks` from `/opt/razor` are now in 
    `/opt/puppetlabs/server/apps/razor-server/share/razor-server`
+ IMPROVEMENT: Updating Torquebox to 3.1.2 and JRuby to 1.7.19.

## 1.3.0 - 2016-05-19

### API changes

+ NEW: Added "has_macaddress" tag matcher. Use this rather than
  `["fact", "macaddress"]`.
+ NEW: Added `config` collection to display active config settings.
+ NEW: Added `allow_localhost` config to allow bypassing authentication when
  requests originate from localhost.
+ BUGFIX: "microkernel.debug_level" is now no longer ignored.

## 1.2.0 - 2016-03-08

### API changes

+ NEW: Added positional arguments to API. These will be included in the help
  for each command.
+ IMPROVEMENT: Add datatype for `node` argument of `set-node-hw-info` command.
  The metadata for this argument wasn't included before, and is now declared
  properly as a String.

### Task changes

+ IMPROVEMENT: Updated and standardized documentation and metadata for existing
  stock tasks. Labels, descriptions, and README.md files inside these stock
  tasks should now be up-to-date.
+ IMPROVEMENT: Updated Debian and Ubuntu stock tasks to use Pacific Time rather
  than Central Time and UTC, respectively.

### Other

+ BUGFIX: When a repo is deleted, the repo directory will also be deleted if it
  downloaded and extracted an ISO with the `iso-url` property.
+ BUGFIX: Nodes will match tags even if the node is already marked installed
  (through e.g. the `protect_new_nodes` config) or bound to a policy.
+ NEW: Added flag "allowunsigned" to allow unsigned drivers to be added to the
  WinPE image for Windows installations.
+ IMPROVEMENT: Made the Powershell script that builds Razor's WinPE image more
  robust in its error handling.
+ IMPROVEMENT: Added documentation for the `update-broker-configuration` command
  to api.md.

## 1.1.0 - 2015-11-12

### Incompatible changes

+ The service will now run on port 8150 for HTTP. This will be updated
  through packaging.

### Other

+ BUGFIX: The EL7 packages will now start the razor-server service properly.
+ BUGFIX: Tasks created through the `create-task` command will now find
  the correct boot stage, rather than feeding the `default` stage at each boot.
+ BUGFIX: Old hook configuration can now be removed if the hook's
  configuration.yaml is modified to remove an attribute.
+ BUGFIX: Actually use separate message queue for hook execution. This
  previously used the same queue as the database messages.
+ BUGFIX: The unused `windows_download_url` property of the `puppet-pe` broker
  has been removed in favor of `windows_agent_download_url`, an optional URL
  indicating where to download the Windows PE agent. 
+ NEW: Added stock hook for dynamic assignment of hostnames. More details on
  this new hook can be found in the hostname.hook directory's README.md.
+ NEW: Task added for Windows 2008 R2. Details are on the [Wiki](https://github.com/puppetlabs/razor-server/wiki/Installing-windows).
+ NEW: `hook_execution_path` config.yaml property is a path which will be
  prepended to the default execution path when running hooks.
+ NEW: `reinstall-node` now accepts a `same_policy` argument, which indicates
  that the node should skip over the microkernel and policy-binding stage,
  and just proceed with a reinstall of the current policy.
+ NEW: The `like` tag matcher can be used to match expressions to a regular
  expression. This can be used, for example, to match on a range of MAC
  addresses. 
+ NEW: The `str` tag matcher can be used to convert input (likely numeric)
  into a string.
+ NEW: The `update-broker-configuration` command can be used to update the
  configuration of a broker.
+ IMPROVEMENT: The `puppet` broker has been updated to use URLs to find RPM/DEB
  files for supported OS's.
+ IMPROVEMENT: Stock tasks have been updated to prefer node metadata for both
  `root_password` and `hostname`. These will fall back to the default on the
  policy if the node metadata does not exist.
+ IMPROVEMENT: The Windows stock tasks will prefer node metadata for timezone,
  falling back to Pacific Standard Time.
+ IMPROVEMENT: More verbose and clear log messages will be included for hook
  execution. As part of this, STDERR will be reported as part of the log.
+ IMPROVEMENT: Broker configuration now, like hook configuration, allows the
  usage of the `default` keyword, indicating the starting value for a
  configuration property if not overridden upon creation.
+ IMPROVEMENT: The Windows build-winpe step now allows the addition of extra
  drivers to the generated .wim file. The drivers (.inf extension) need to be
  added to the `extra-drivers` folder inside the build-winpe directory.
+ IMPROVEMENT: For clarity, the build-winpe step will generate `razor-winpe.wim`
  rather than `winpe.wim`. This way, the file can be copied to the razor-server
  without requiring renaming.
+ IMPROVEMENT: Line endings for SetupComplete.cmd.erb are now in Windows format,
  causing the rendered SetupComplete.cmd file to be legible on Windows systems.
+ IMPROVEMENT: The RAZOR_HTTP_PORT environment variable will now be used to
  tell the razor service which port to use for HTTP traffic.
+ IMPROVEMENT: The `bootstrap` URL will now guess what the correct http_port
  value should be, typically falling back to the URL used for the `/bootstrap`
  request. 

## 1.0.1 - 2015-06-11

### Other

+ NEW: The `update-hook-configuration` command allows changing an existing
  hook's configuration, which should help with hook script creation.
+ NEW: The `run-hook` command allows arbitrary execution of a hook.
+ NEW: The `store_hook_input` and `store_hook_output` config settings can
  toggle storing the input and output for a hook script in the event log. These
  are disabled by default.
+ IMPROVEMENT: Determine the WinPE drive letter programmatically for Windows
  tasks.
+ IMPROVEMENT: Show severity for an event in node log view.
+ IMPROVEMENT: Log when the `puppet-pe` broker fails execution.

## 1.0.0 - 2015-06-08

### Incompatible changes

+ Some of the stock tasks have been renamed. If you used the previous ubuntu
  tasks, these have been changed to a more standard naming scheme. The `ubuntu`
  task points to Trusty, and the others are `ubuntu/precise` and `ubuntu/lucid`
  instead of the previous longer names e.g. `ubuntu_precise_amd64`. Use the new
  commands `update-policy-task` and `update-repo-task` to change existing
  policies and repos to use these new task names.
+ `modify_policy_max_count` now uses `no_max_count` to indicate that the
  policy should be unbounded.

### Other

+ NEW: The `update-policy-task` command can be used to migrate policies if the
  associated task's name changes.
+ NEW: The `update-repo-task` command can be used to migrate repos if the
  associated task's name changes.
+ NEW: The `secure_api` config property can be used to ensure that
  communications with /api are secure. When this is true, all calls to the
  namespace need to be over HTTPS with SSL, and otherwise will return a 404.
  The actual configuration of this happens in Torquebox's configuration. By
  default, this property is false (no change from current behavior).
+ IMPROVEMENT: `HTTP_PORT` and `HTTPS_PORT` will be used to set the ports for
  HTTP and HTTPS communication instead of `RAZOR_PORT`
+ NEW: If the razor-server is configured to use SSL, any HTTPS calls to
  /api/microkernel/bootstrap must include the `http_port` argument.
+ NEW: The `like` matcher function will allow Regex-based string evaluation
  when matching nodes to tags.
+ NEW: The `str` matcher function will convert numbers, strings, and booleans
  to strings.
+ BUGFIX: Any metadata that returned an array or hash caused unreliable
  behavior when referenced in tags. This will now return a helpful error.
+ IMPROVEMENT: The task link in `create-policy` is now optional, deferring to
  the task in the repo if not provided.
+ NEW: Configuration now allows a defaults file. The RAZOR_CONFIG_DEFAULTS
  environment variable can tell Razor where this file exists, or it will
  look for /opt/razor/config-defaults.yaml by default. Any config absent from
  the normal config.yaml file will be pulled from here next.
+ IMPROVEMENT: The redhat task now allows node metadata to run the RHN
  subscription command. `rhn_username`, `rhn_password`, and `rhn_activationkey`
  can be used for this. See the README.md inside the task for more information.
+ IMPROVEMENT: MAC addresses supplied with 'net' prefixes will now be
  standardized to match those in the 'mac' fact.
+ NEW: Metadata can now be structured. If the metadata is either an array or an
  object, this can be used in tasks, hooks, and brokers, but not tags currently.
+ IMPROVEMENT: Each stock task that references node metadata now has a README.md
  file that describes the values it uses.
+ IMPROVEMENT: The redhat task now uses the node's "timezone" metadata value to
  set the time
+ IMPROVEMENT: Now using a later version of the Sequel gem.
+ IMPROVEMENT: Better logging when files are being retrieved from Razor in
  brokers and tasks.
+ IMPROVEMENT: API standardized to use underscores for property names.
+ NEW: `aliases` added to API for better datatype recognition in argument
  metadata.
+ IMPROVEMENT: The hooks.md file has been revamped, now including a full
  example.
+ BUGFIX: Tags on policies are now being serialized properly when passed to the
  hook as input.

## 0.16.1 - 2015-01-12

### Other

+ BUGFIX: Fixing a bug that would not allow new events to be created
  in the database due to a plugin conflict.

## 0.16.0 - 2015-01-05

### Incompatible changes

+ Tags will be unique in a case-insensitive manner. Previously, tags
  could have existed as e.g. 'mytag' and 'MyTag'. A migration in this
  release will rename conflicting tags, appending a digit to the end,
  e.g. 'mytag' and 'MyTag1'.
+ The `update-node-metadata` command no longer accepts the `all`
  argument. This argument should have never been accepted by the 
  command, and had no effect. Instead, `modify-node-metadata` can be 
  called with either the `clear` argument to remove all keys, or the 
  `update` argument to set all keys to certain values, which achieves 
  the same function.

### API changes

+ `create-hook` and `delete-hook` are two new commands for managing
  hooks.
+ `events` collection now displays events from the Razor server.
  This can be scoped by querying `nodes/$name/log` or
  `hooks/$name/$log`.
+ Various collections can now be limited and offset by supplying
  `limit` and `start` parameters. These parameters can be discovered
  via the logically prior endpoint. For `/api/collections/events`,
  this is in `/api`. For `/api/collections/nodes/$name/log`, this is
  in `/api/collections/nodes/$name`.
+ Help text now exists for razor-client in addition to just the API.
  This is accessible via a GET on the command's endpoint, where the
  new 'examples' key in the help text has 'api' and 'cli' as sub-keys.
+ The `create-repo` command now accepts a `--no-content` argument,
  which signifies that neither the `--iso-url` nor the `--url`
  arguments will be supplied, and instead an empty directory will be
  created.
+ `create-tag` is now idempotent.

### Task changes

+ NEW: Added Windows tasks for 2012R2.
+ NEW: Added Ubuntu tasks for Lucid (10.04) and Trusty (14.04).
+ NEW: Windows tasks can execute brokers.
+ BUGFIX: Fixed existing Debian i386 task.
+ IMPROVEMENT: Windows default task (8 pro) now utilizes node's
  root_password value rather than the default `razor`.
+ IMPROVEMENT: Windows tasks now use newer wimboot (2.4.0)
+ IMPROVEMENT: Debian and Ubuntu (Trusty only) can allow hostname
  without '.' for fetching preseed file.

### Other

+ NEW: Hooks. See `hooks.md` for details on how to write and use hooks.
+ NEW: Separate API and CLI help examples: There are now two formats for help
  examples. The new CLI format shows help text as a standard razor-client
  command.
+ IMPROVEMENT: Updating Torquebox to 3.1.1 and JRuby to 1.7.13.
+ BUGFIX: Fixing heap space issues with default settings in Torquebox.
+ IMPROVEMENT: Standardizing behavior for creating two entities whose names only
  differ in case.
+ IMPROVEMENT: Adding idempotency in `create-tag`.
+ NEW: Exposing IPMI details (username and hostname) in `razor --full nodes`.
+ NEW: Provide warning in `create-policy` if the user attempts to create a
  tag, a feature which was removed in 0.15.0.
+ IMPROVEMENT: `create-broker` now accepts argument `c` as an alias for
  `configuration`.
+ NEW: Brokers can now use arbitrary executable files for installation,
  which is most helpful for Powershell in Windows.
+ BUGFIX: Some attempts to contact Razor server are retried upon failure.
+ BUGFIX: Disallowing old versions of Sinatra where download of initrd.gz
  would hang.

## 0.15.0 - 2014-05-22

### Incompatible changes

+ the way that tasks and templates are stored on disk has changed. All
the builtin tasks have been updated to use the new layout; if you wrote
your own custom tasks, you will have to adjust them as described on the
[migration page](http://links.puppetlabs.com/razor-migration-task-revamp)

  The task layout has changed in the following way:
  1. All files for a task `name` must now be in a directory `{name}.task`
     on the `task_path` configured in `config.yaml`; the `task_path`
     defaults to the `tasks` directory in the Razor source tree
  2. The metadata file for a task must now be located in
     `{name}.task/metadata.yaml` rather than `{name}.yaml`
  3. The search path for templates does not take the `os_version` of a
     task into account anymore, but simply relies on the `name` of the
     task, and that of `base_tasks` if the task inherits from another
     task. The search path for a template is now
     `{name}.task:{base_task}.task: ... further base tasks ...:/common`.
+ `create-repo` now requires a `task` argument. The argument must be the
  name of an existing task; use `razor tasks` to get a list of tasks your
  server knows about.
+ The `create-policy` function no longer creates tags in addition to
  creating a policy.

### API Changes
+ The version of the server is now included in the output of `GET /api`;
  this is not the version of the API, but simply the version of the server
  code and should not be used to determine capabilities of the API. It is
  simply included to ease bug reporting etc.
+ A `GET` request against a command's URL now returns metadata about the
  command, including a help text and information about the accepted
  parameters.
+ Commands now return the URL of a 'command' object that can be used to
  track the progress of the background work of a command, in particular
  that of the `create-repo` command. (RAZOR-7)
+ All the `create-*` commands are now idempotent. When a `create-*` command
  is issued a second time, it will return an HTTP status of 202 if it is
  identical to the first `create-*` request, and a status of `409 Conflict`
  if there are differences between the two. (RAZOR-185)
+ The commands `create-policy`, `create-repo`, and `move-policy` now accept
  the short reference form, e.g. `"task": "TASK_NAME"` instead of `"task":
  { "name": "TASK_NAME" }`
+ Changing a tag via `update-tag-rule` would not retag existing nodes to
  reflect the changes in the tag. (RAZOR-250) Furthermore, if evaluating a
  new tag against all nodes caused a failure against one node, retagging
  nodes erroneously stopped. Razor now logs the evaluation failure in the
  affected node's log and continues evaluating the tag against other
  nodes. (RAZOR-254)
+ Validation of command parameters is now much more thorough and produces
  more consistent error messages
+ When doing a `delete-repo`, clean the storage on disk used by the repo
  (RAZOR-202) Avoid requiring two tempfiles for each downloaded ISO
  (RAZOR-73)
+ New commands
  + the `set-node-hw-info` command can be used to manually change he
    hardware info for a node used to identify it on boot, e.g. to reflect a
    hardware change
  + the `register-node` command can be used to manually preregister nodes
    and optionally mark them as installed and therefore ineligible for
    changes by Razor

### Task changes
+ fix error in preseed files for debian.task and ubuntu.task (RAZOR-121)
+ fix an error in `os_boot.erb` for ubuntu.task when repository names
  contained underscores (Maish Saidel-Keesing, commit 669d9113)

### Other
+ Check that the database uses the version of the schema that the code
  expects; if that is not the case, all requests to the server will produce
  a '500 Internal error' with a friendly reminder to migrate the database.
+ It is now possible to extend the Microkernel at runtime by providing a
  zip file with code that gets downloaded to the Microkernel. The
  `microkernel.extension-zip` configuration setting, if configured with the
  path of an existing zip file, will be downloaded and unpacked on the MK
  image before the agent runs.  This allows runtime addition of facts to
  the MK without a rebuild of the ISO image. [More details](https://github.com/puppetlabs/razor-server/blob/master/doc/mk-extension.zip.md) (based on work by Chris Portman)
+ The way we identify nodes has seen some significant change: we treat the
  data that we gather from iPXE as provisional, and reidentify a node once
  it checks in from the Microkernel using facts. It is now possible to use
  some facts for node identification, controlled by `facts.match_on`, for
  example so that the UUID's of hard disks on a machine are ultimately used
  to identify the node. That ensures that even if the mainboard of a node
  is replaced that Razor will find that node again in its database. (based
  on work by Chris Portman) (RAZOR-174) (RAZOR-218)
+ DHCP will be retried when it fails, to better support networks that take
  time to configure.  (802.1x, trunking, and similar issues are common
  causes.) You need to regenerate the `bootstrap.ipxe` on your TFTP server
  to take advantage of that; you can retrieve that file by issuing a `GET
  /api/microkernel/bootstrap` on an updated server
+ `sanboot` metadata field support: if this is set to (boolean) true in
   the node metadata, the `sanboot` workaround for firmware PXE booting
   bugs will be enabled on that specific node.
+ By default, Razor considers all new nodes that it discovers as eligible
  for installation. Setting the `protect_new_nodes` configuration setting
  to `true` will mark all newly discovered nodes as "installed", causing
  them to boot locally and protecting them from any modifications by Razor
  until explicitly marked as available via `reinstall-node`. New nodes will
  still be inventoried when the boot against Razor for the very first time,
  but will boot locally thereafter.
+ The matching language for rules now has `upper` and `lower` functions for
  converting a string to upper- and lower-case respectively.
+ All human-readable messages are now localizable (using GNU gettext),
  though we only ship an English translation so far. The message catalog
  can be found in `locales/` if you want to have a go at translating ;)
+ Properly reboot nodes via IPMI, rather than turning the node off (commit
  d03fc713)

## 0.14.1 - 2014-02-03

Release notes are missing for this release

## 0.14.0 - 2014-01-30

Release notes are missing for this release

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
