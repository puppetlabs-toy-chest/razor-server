## Sample counting hook

### Prerequisites

This hook requires that [jq](http://stedolan.github.io/jq/) is installed. This
must be contained in $PATH in order for the hook scripts to succeed.

### Purpose

This hook performs two potentially useful things:

- It will count the number of times each hook event has been triggered. The
  value for each event can be found in `razor hooks $name` under
  `configuration`:

    ```
    $ razor hooks hook_name
    From https://razor.example.com:8151/api/collections/hooks/hook_name:

               name: hook_name
          hook_type: counter
      configuration:
                                    nodeboot: 11
                           nodeboundtopolicy: 4
                                 nodedeleted: 1
                            nodefactschanged: 4
                         nodeinstallfinished: 2
                              noderegistered: 3
                       nodeunboundfrompolicy: 1

    Query additional details via: `razor hooks hook_name [configuration, log]`
    ```

- It will update the node's `last_hook_execution` metadata value to reflect the
  last hook the node has triggered, visible via `razor nodes $name`:

    ```
    $ razor nodes node1
      From https://razor.example.com:8151/api/collections/nodes/node1:

                name: node1
            dhcp_mac: 00:00:00:00:00:00
               state:
                           installed: policy_name
                        installed_at: 2015-04-01T00:00:00-07:00
                               stage: boot_local
        last_checkin: 2015-04-01T00:00:01-07:00
            metadata:
                        last_hook_execution: node-booted
                tags: some_tag

      Query additional details via: `razor nodes node1 [facts, hw_info, log, metadata, policy, state, tags]`
    ```

### How to install

This hook comes with Razor; all you will need to do is create an instance of
the hook via `razor create-hook --name counter --hook-type counter`.

### Viewing the hook's activity log

To view the status of the hook's executions, see `razor hooks $name log`:

        timestamp: 2015-04-01T00:00:00-07:00
           policy: policy_name
            cause: node-booted
      exit_status: 0
         severity: info
          actions: updating hook configuration: {"update"=>{"node-booted"=>1}} and updating node metadata: {"update"=>{"last-hook-execution"=>"node-booted"}}