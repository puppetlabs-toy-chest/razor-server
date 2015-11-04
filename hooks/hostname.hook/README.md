## Sample hostname assignment hook

You can use a hook to create more advanced dynamic hostnames than the simple incremented pattern --- `$\{id\}.example.com` --- from the `hostname` property on a policy. This type of hook calculates the correct hostname and returns that hostname as metadata on the node. To do so, it uses a basic counter system that stores how many nodes have bound to a given policy.

This hook is intended to be extended for cases where an external system needs to be contacted to determine the correct hostname. In such a scenario, the new value will still be returned as metadata for the node.

### Prerequisites

Ruby must be installed in `$PATH` for the hook script to succeed. If it is not included, add it via the `hook_execution_path` property in the config.yaml file.

### Install the Hook

This hook comes with Razor. To use it, create an instance of
the hook with the following command:


        razor create-hook --name some_policy_hook --hook-type hostname \
            --configuration policy=some_policy \
            --configuration hostname-pattern='${policy}${count}.example.com'


### How It Works

Running the above `create-hook` command kicks off the following sequence of events:

1. The counter for the policy starts at 1.
2. When a node boots, the `node-bound-to-policy` event is triggered.
3. The policy's name from the event is then passed to the hook as input.
4. The hook matches the node's policy name to the hook's policy name.
5. If the policy matches, the hook calculates a rendered `hostname-pattern`:
   - It replaces `${count}` with the current value of the `counter` hook
     configuration.
   - It left-pads the `${count}` with `padding` zeroes. For example, if the hook
     configuration's `padding` equals 3, a `count` of 7 will be rendered as
     `007`.
   - It replaces `${policy}` with the name of its policy.
6. The hook then returns the rendered `hostname-pattern` as the node metadata
   of `hostname`.
7. The hook also returns the incremented value for the counter that was used so
   that the next execution of the hook uses the next value.

If multiple policies require their own counter, create multiple instances of
this hook with different `policy` and/or `hostname-pattern` hook configurations.

### Viewing the Hook's Activity Log

To view the status of the hook's executions, see `razor hooks $name log`:

        timestamp: 2015-04-01T00:00:00-07:00
           policy: policy_name
            cause: node-bound-to-policy
      exit_status: 0
         severity: info
          actions: updating hook configuration: {"update"=>{"counter"=>2}} and updating node metadata: {"update"=>{"hostname"=>"policy_name1.example.com"}}
