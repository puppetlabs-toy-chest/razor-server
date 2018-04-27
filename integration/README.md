Integration Tests
===========================

This folder contains integration tests for the Razor project. These tests were originally written by the QA team
at Puppet Labs and is actively maintained by the QA team. Feel free to contribute tests to this folder as long
as they are written with [Beaker](https://github.com/puppetlabs/beaker) and follow the guidelines
below.

## Integration?

The Razor project already contains RSpec tests and you might be wondering why there is a need to have a set of
tests separate from those tests. At Puppet Labs we define an "integration" test as:

> Validating the system state and/or side effects while completing a complete life cycle of user stories using a
> system. This type of test crosses the boundary of a discrete tool in the process of testing a defined user
> objective that utilizes a system composed of integrated components.

What this means for this project is that we will install and configure all infrastructure needed in a real-world
Razor environment.

## Running Tests

Included in this folder under the "test_run_scripts" sub-folder are simple Bash scripts that will run suites of
Beaker tests. This scripts utilize environment variables for specifying test infrastructure. For security
reasons we do not provide examples from the Puppet Labs testing environment.

## Documentation

Each sub-folder contains a "README.md" that describes the content found in the sub-folder.
