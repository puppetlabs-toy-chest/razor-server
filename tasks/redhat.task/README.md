# Task notes for Redhat 6

## Node Metadata

- 'rhn_username' (optional) - This will be substituted into the kickstart
  file for the subscription username used during installation.
  - Default: If this and 'rhn_password' are omitted, the subscription will
    not be performed in the kickstart file.
- 'rhn_password' (optional) - This will be substituted into the kickstart
  file for the subscription password used during installation.
  - Default: If this and 'rhn_username' are omitted, the subscription will
    not be performed in the kickstart file.
- 'rhn_activationkey' (optional) - This will be substituted into the kickstart
  file for the activation key used during installation.
  - Default: "--auto-attach" will be used instead if 'rhn_username' or
    'rhn_password' is supplied.
- 'timezone' (optional) - This is the string corresponding to the timezone for
  the node.
  - Default: America/Los_Angeles
- 'root_password' (optional) - This is an override for the root_password that
  exists on the node when it binds to a policy. If this is provided, it will be
  used for the node's root password.
- 'hostname' (optional) - This is an override for the hostname that exists
  on the node when it binds to a policy. If this is provided, it will be used
  for the node's hostname.