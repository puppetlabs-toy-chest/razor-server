# Task notes for Fedora 23

## Node Metadata

- 'timezone' (optional) - This is the string corresponding to the timezone for
  the node.
  - Default: America/Los_Angeles
- 'root_password' (optional) - This is an override for the root_password that
  exists on the node when it binds to a policy. If this is provided, it will be
  used for the node's root password.
- 'hostname' (optional) - This is an override for the hostname that exists
  on the node when it binds to a policy. If this is provided, it will be used
  for the node's hostname.