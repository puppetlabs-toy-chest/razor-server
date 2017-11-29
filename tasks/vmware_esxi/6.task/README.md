# Task notes for VMWare ESXi 6

## Node Metadata

- 'root_password' (optional) - This is an override for the root_password that
  exists on the node when it binds to a policy. If this is provided, it will be
  used for the node's root password.
- 'hostname' (optional) - This is an override for the hostname that exists
  on the node when it binds to a policy. If this is provided, it will be used
  for the node's hostname.

## Notes

- This task will not trigger a run of any broker.
