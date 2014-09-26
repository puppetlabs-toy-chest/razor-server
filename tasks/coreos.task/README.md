# CoreOS task for Puppet Labs Razor

## Definition

Allowing for full clusters of CoreOS to be deployed, automatically
configuring the setup with heavy use of Razor's node-metadata function to
enable features like etcd configuration, fleet metadata, formatting of
drives and automatic addition of SSH keys. Since the node-metadata is
applied on all nodes, their value can easily be updated with different
settings on a per-node basis if wanted.

## Dependencies

 - Access to either CoreOS public PXE repos, or added ISO-repo in Razor.
 - Discovery token, get a new one here [here](http://discovery.etcd.io/new)
 - Internet access to download Kelsey Hightower's setup-network-environment
   binary to set the public IP of etcd correctly.

## Usage

Create a repo based on ISOs as normal or use CoreOS PXE repos like this:

```
{
  "name": "coreos",
  "url":  "http://stable.release.core-os.net/amd64-usr/current",
  "task": "coreos"
}
```

Create tags for whatever you have in your DC that you'd like to use for CoreOS.

```
{
  "name": "coreos",
  "rule":
  ["and",
  ["=", ["num", ["fact", "processorcount"]], 1],
  ["=", ["fact", "is_virtual"], "true"]]
}
```

Create a policy and make sure you exchange the following node-metadata with
your own:

 - persistent-drive
 - fleet-metadata
 - discovery-token
 - ssh-rsa

```
{
  "name": "coreos",
  "repo": { "name": "coreos" },
  "task": { "name": "coreos" },
  "broker": { "name": "noop" },
  "enabled": true,
  "hostname": "host.lab.purevirtual.eu",
  "root_password": "secret",
  "max_count": 10,
  "node-metadata": {
	  "persistent-drive": "sda",
	  "fleet-metadata": "region=us-east",
	  "discovery-token": "7577ba844d87b990e2d79717852fb4d4",
	  "ssh-rsa": "AAAAB3NzaC1yc2EAAAADAQABAAABAQCltHm3vFFhRun3u2ka6pK7pUVh44jX2vwdCx6R4t6N4HyHWemf9WzGVhjFYupoxYTbtyqkCCKyMFXEFULRVsfRZ/7wl3IPZGsQMXUSDFYaPfhrpkvj8mJbghrSSj2rmlrKKgA2Jl0Y5jXR+W+sCsdnilquh/vWcWcbUlkcGlK0SYrkfVnfsmmSFhSWa56kCz69B35un3CuX4fEWvIW1bhq+6IruB4DewVlfz6pXE4fHUK0oiqlvlv7boLlR4kMoQ+49DjKlRyJdkHZJtaW3RvKBaF6qbTTPC24tETDKs1GIv2tTDmxl1O1RFG5J91kq70yp6KrB+NQ6i/AnLuRmRmF"
	  },
  "tags": [{ "name": "coreos"}]
}
```

## More info

More info can be found here: blog from CoreOS

## Creator

Jonas Rosland
