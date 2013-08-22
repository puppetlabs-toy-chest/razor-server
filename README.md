# Razor server

This code is still in development mode; that means that we might make
backwards incompatible changes, especially to the database schema which
would force you to rebuild all the machines that Razor is managing. Razor
will become stable RSN.

## Getting in touch

* on IRC: `#puppet-razor` on [freenode](http://freenode.net/)
* mailing list: [puppet-razor@googlegroups.com](http://groups.google.com/group/puppet-razor)

## Getting started

The Wiki has all the details; in particular look at

* [Installation](https://github.com/puppetlabs/razor-server/wiki/Installation): how to get a Razor environment up and running
* [Geting started](https://github.com/puppetlabs/razor-server/wiki/Getting-started): using the CLI to do useful things
* [Developer setup](https://github.com/puppetlabs/razor-server/wiki/Developer-setup): for when you feel like hacking

## What does Razor do anyway ?

Project Razor is a power control, provisioning, and management application
designed to deploy both bare-metal and virtual computer resources. Razor
provides broker plugins for integration with third party configuration
systems such as Puppet.

Razor does this by discovering new nodes using
[facter](https://github.com/puppetlabs/facter), tagging nodes using facts
based on user-supplied rules and deciding what to install through matching
tags to user-supplied policies. Installation itself is handled flexibly
through ERB templating all installer files. Once installation completes,
the node can be handed off to a broker, typically a configuration
management system. Razor makes this handoff seamless and flexible.

This is a 0.x release, so the CLI and API is still in flux and may
change. Make sure you __read the release notes before upgrading__

## Razor MicroKernel

The [MicroKernel](https://github.com/puppetlabs/razor-el-mk) is a small OS
image that Razor boots on new nodes to do discovery. It periodically
submits [facts](https://github.com/puppetlabs/facter) about the node and
waits for instructions from the server about what to do next, if anything.

A [prebuild image](http://links.puppetlabs.com/razor-microkernel-001.tar)
is available.

## Reference

* Original Razor Overview: [Nickapedia.com](http://nickapedia.com/2012/05/21/lex-parsimoniae-cloud-provisioning-with-a-razor)
* Razor Session from PuppetConf 2012: [Youtube](http://www.youtube.com/watch?v=cR1bOg0IU5U)


## License

Razor is distributed under the Apache 2.0 license.
See [the LICENSE file](LICENSE) for full details.
