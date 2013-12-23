# Razor Authentication Structure

This documents the current authentication trees available in Razor, and their
structure.  This will be useful in setting up your own roles.

## Commands -- changes to the system

All the commands authorize in this structure:

    commands:${name}:${subject}

`name` is the name of the command (eg: `create-repo`, `delete-repo`).

`subject` is the name of the main object (eg: `create-repo:esxi55`, `delete-repo:esxi55`).

When a command applies to multiple subjects, we will assert the permission
required for *all* of them.


## Queries -- reading data from the system

Queries authenticate in the structure:

    query:${collection}:${name}

The one exception is the node logs:

    query:${collection}:${name}:logs

`collection` is the name of the collection (eg: `tags`, `brokers`).

`name` is the name of the entity (eg: `tags:virtual`, `brokers:puppet`).

Reading node logs requires does not require reading data for the node, but
reading data for the node implicitly grants reading logs.
