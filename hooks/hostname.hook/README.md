## Sample counting hook

### Prerequisites

This hook requires that ruby is installed. This must be contained in $PATH in
order for the hook script to succeed.

### Purpose

This hook performs dynamic hostname assignment. It uses a basic counter system,
storing how many nodes have bound to a given policy.

### How to install

This hook comes with Razor; all you will need to do is create an instance of
the hook via:

```
razor create-hook --name some_policy_hook --hook-type hostname \
                  --configuration policy=some_policy \
                  --configuration hostname-pattern='${policy}${count}.example.com'
```

### How it works

The order of events is as follows:

1. The counter for the policy starts at 1.
2. When a node boots, the `node-bound-to-policy` event is triggered.
3. The policy's name from the event is then passed to the hook as input.
4. The hook matches the node's policy name to the hook's policy name.
5. If the policy matches, the hook calculates a rendered hostname pattern:
   - It replaces `${count}` with the current value of the `counter` hook 
     configuration.
   - It left-pads the `${count}` with `padding` zeroes. E.g. If the hook
     configuration's `padding` equals 3, a `count` of 7 will be rendered as
     `007`.
   - It replaces `${policy}` with the name of its policy.
6. The hook then returns the rendered hostname-pattern as the node metadata
   of `hostname`.
7. The hook also returns the incremented value for the counter that was used.

If multiple policies require their own counter, create multiple instances of
this hook with different `policy` and/or `hostname-pattern` hook configurations.

### Viewing the hook's activity log

To view the status of the hook's executions, see `razor hooks $name log`:

        timestamp: 2015-04-01T00:00:00-07:00
           policy: policy_name
            cause: node-bound-to-policy
      exit_status: 0
         severity: info
          actions: updating hook configuration: {"update"=>{"counter"=>2}} and updating node metadata: {"update"=>{"hostname"=>"policy_name1.example.com"}}
