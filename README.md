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

