# Action Client

Plugin command line for running commands over nodes

## Overview

## Installation

### Preconditions

The following are required to run this application:

* OS:     Centos7
* Ruby:   2.6+
* Bundler

### Manual installation

Start by cloning the repo, adding the binaries to your path, and install the gems:

```
git clone https://github.com/openflighthpc/action-client-ruby
cd action-client-ruby
bundle install --without development test --path vendor
```

### Configuration

These application needs a couple of configuration parameters to specify which server to communicate with. Refer to the [reference config](etc/config.yaml.reference) for the required keys. The configs needs to be stored within `etc/config.yaml`.

```
cd /path/to/client
touch etc/config.yaml
vi etc/config.yaml
```

## Basic Usage

The list of available commands is retrieved each time the application is called automatically. This means no cache needs to be established before using the application. Instead the command line can be called directly:

```
flight-action
```

As the application needs the upstream service for the commands, it is possible for the base command to error. This could be for various reasons as described by the error message. The following are common errors and suggestions how to rectify them.

```
# NOTE: The following error messages have not been standardized and may change without notice

# Connection errors indicate the upstream server isn't currently running
# Fix 1: Check the 'base_url' config value is correct
# Fix 2: Confirm the upstream service is running
flight-action
> flight-action: Failed to open TCP connection to localhost:6304 (Connection refused - connect(2) for "localhost" port 6304

# Authorization errors indicate there is an issue with the 'jwt_token` config value
# Fix: Regenerate the token and try again
flight-action
> flight-action: You are not authorized to perform this action

# NOTE: Developers Only
# The --trace flag does not work for these types of errors as ARGV is not parsed until a command is executed
```

A detailed walk through of the commands is not possible as they are defined dynamically in content. This application does not ship with any default commands. The following guide illustrates in general how to use the CLI to perform various actions. The `<cmd>` is a stand-in for the name of the command being executed.

```
# Run a command for a single node
flight-action <cmd> slave1

# Run a command over mutliple nodes
# (Requires exploding groups support - contact your server administrator)
flight-action <cmd> --group node1,node3,slave[01-10]

# Run a command over all the nodes in a group
# (Requires named groups support - contact your server administrator)
flight-action <cmd> --group gpus

# Save the outputs in a directory for a node
flight-action <cmd> slave1 -output /path/to/dir
# Creates:
#   /path/to/dir/slave1.status
#   /path/to/dir/slave1.stderr
#   /path/to/dir/slave1.stdout

# Similarly save the output for a group of nodes
flight-action <cmd> --group gpus -o relative/path/from/working/dir
```

## Tailored usage

`flight-action` also supports a tailored usage mode.  In tailored usage mode
the available commands and options are limited to provide a more tailored user
experience.

To start `flight-action` in tailored usage mode, set the environment variable
`FLIGHT_ACTION_NAMESPACE` and optionally `FLIGHT_ACTION_DESCRIPTION`.  In
tailored usage mode, only commands matching the prefix
`${FLIGHT_ACTION_NAMESPACE}-` are available.

For example a power-action command could be created using the following bash
function.

```
function power-action() {
  FLIGHT_ACTION_NAMESPACE=power FLIGHT_ACTION_DESCRIPTION="Execute power ations" flight-action "$@"
}
```

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License
Eclipse Public License 2.0, see LICENSE.txt for details.

Copyright (C) 2019-present Alces Flight Ltd.

This program and the accompanying materials are made available under the terms of the Eclipse Public License 2.0 which is available at https://www.eclipse.org/legal/epl-2.0, or alternative license terms made available by Alces Flight Ltd - please direct inquiries about licensing to licensing@alces-flight.com.

ActionClient is distributed in the hope that it will be useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more details.

