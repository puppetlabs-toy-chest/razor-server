# Razor server

This is a rewrite of the Razor server

LET ME KNOW IF YOU INTEND TO HACK ON THIS - OTHERWISE I MIGHT DO NASTY
THINGS TO THE REPO

## Getting started

Currently, the Razor server requires a certain amount of manual setup, and
is only suitable for development. You need the following to work on it:

* Make sure you have JRuby 1.7.4 and Bundler, installed
  - RVM should work fine out of the box
  - your platform JRuby or a binary JRuby should also be fine
* Make sure you have a PostgreSQL database available
* Create a database in that PostgreSQL instance
* cd into this directory
* Run 'bundle install'
* cp config.yaml.sample config.yaml
* Edit config.yaml and adjust, at a very minimum the `database_url` for
  development and test (these should be different databases)
  - in most development cases, with no authentication, you can just put
    your database name in the obvious place in the URL.
* Run `rake db:migrate`
* Run `torquebox deploy`
* Run `torquebox run` to start the server
  - `torquebox run --jvm-options='-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled'`
    is recommended if you expect to modify code and redeploy regularly, to
    reduce problems with running out of heap space in the JVM.

At this point the application is running on port 8080, ready to
serve connections.

If you make changes to your code, run `torquebox deploy` again to notify a
running server that it should reload your application.  Presently, real-time
reloading is not enabled.


## Running tests

* Run `rake spec:all` or `rspec spec`

As of now, coverage generation through SimpleCov is automatically enabled for
all spec test runs.  This doesn't substantially change the runtime of the
tests.

You should set `JRUBY_OPTS='--debug'` in your environment to avoid the warning
about reduced coverage accuracy -- or simply ignore the warning, which does
not change the accuracy of the tests themselves.

(The same option is required if you intend to use a debugger with JRuby.)


## JRuby, TorqueBox?  Madness!

Not really; part of the promise of Razor is that it can help manage a pool of
machines, including reprovisioning.  This means it lives as part of the boot
process of every server on the network.  If that goes down, bad things follow.

JRuby and TorqueBox help deliver a highly available solution at minimal cost,
especially when focused on clustering multiple machines to provide high levels
of resilience to day to day maintenance or upgrades.

## Deploying

1. Put the
   [iPXE firmware](http://boot.ipxe.org/undionly.kpxe) `undionly.kpxe` on
   your TFTP server
1. Have the Razor server give you a default iPXE boot file with

       curl -o bootstrap.ipxe http://razor.example.org/api/microkernel/bootstrap?nic_max=NNN

   The parameter nic_max is the maximum number of interfaces with DHCP that
   you plan to encounter on your machines and must be an integer not
   starting with '0'; it defaults to 4. Put this file also on your TFTP
   server.
1. Arrange for your DHCP server to tell machines that are running the iPXE client
   to load `bootstrap.ipxe`, and all other machines to boot `undionly.kpxe`

### With dnsmasq

If you are using [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html),
the following configuration settings should suffice

    # This works for dnsmasq 2.45
    # iPXE sets option 175, mark it for network IPXEBOOT
    dhcp-match=IPXEBOOT,175
    dhcp-boot=net:IPXEBOOT,bootstrap.ipxe
    dhcp-boot=undionly.kpxe
    # TFTP setup
    enable-tftp
    tftp-root=/var/lib/tftpboot

You then need to copy `undionly.kpxe` and `bootstrap.ipxe` to
`/var/lib/tftpboot`
