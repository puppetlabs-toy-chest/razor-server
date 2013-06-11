# Razor server

This is a rewrite of the Razor server

LET ME KNOW IF YOU INTEND TO HACK ON THIS - OTHERWISE I MIGHT DO NASTY
THINGS TO THE REPO

## Getting started

Currently, the Razor server requires a certain amount of manual setup, and
is only suitable for development. You need the following to work on it:

* Make sure you have Ruby 1.9.3, Bundler, and Thin installed
* Make sure you have a PostgreSQL database available
* Create a database in that PostgreSQL instance
* cd into this directory
* Run 'bundle install'
* cp config.yaml.sample config.yaml
* Edit config.yaml and adjust, at a very minimum the `database_url` for
  development and test (these should be different databases)
* Run 'rake db:migrate'
* Start your server; either with `thin start`, or if you have shotgun with
  `shotgun -p 3000`

## Running tests

* Run `rake spec:all`
