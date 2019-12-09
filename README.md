# Power Server

Platform agnostic utility for preforming power commands across a HPC cluster

## Overview


## Installation

### Preconditions

The following are required to run this application:

* OS:           Centos7
* Ruby:         2.6+
* Yum Packages: gcc

The following are required by the example `topology` configuration file. Custom configurations may not need these tools.
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-linux-al2017.html)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest)

### Manual installation

Start by cloning the repo, adding the binaries to your path, and install the gems. This guide assumes the `bin` directory is on your `PATH`. If you prefer not to modify your `PATH`, then some of the commands need to be prefixed with `/path/to/app/bin`.

```
git clone https://github.com/openflighthpc/power-server
cd power-server

# Add the binaries to your path, which will be used by the remainder of this guide
export PATH=$PATH:$(pwd)/bin
bundle install --without development test --path vendor

# The following command can be ran without modifying the PATH variable by
# prefixing `bin/` to the commands
bin/bundle install --without development test --path vendor
```

Additional configuration is required for the `aws` and `az` command lines to work. Please refer to there reference documents on how to install them. This service assumes they have been pre installed and configured with the appropriate credentials.

### Configuration

The application needs the following configuration values in order to run. These can either be exported into your environment or directly set in `config/application.yaml`.

```
# Either set them into the environment
export jwt_shared_secret=<keep-this-secret-safe>

# Or hard code them in the config file:
vim config/application.yaml
```

### Adding Nodes And Platforms

The layout of the cluster is specified in the topology config file which is stored as `config/topology.yaml` by default. It must specify the `nodes` and `platforms` key.

#### Getting Started

A handy example config ships with this application to help you get started. It first
needs to be copied into place:

```
# NOTE: Copying the config into place will maintain the example for future reference
cp config/topology.example.yaml config/topology.yaml
```

All further actions will be preformed on `config/topology.yaml`. A basic list of `nodes` has been provided with this config. It is now safe to remove them.

#### Adding a Platform

The example topology ships with the `aws`, `azure`, and `ipmi` platforms preconfigured. Move onto the nodes section if you wish to use one of these three.

Alternatively a custom platform can be added:

```
platforms:
  my-custom-platform:
    variables: [var1, var2]  # Array of variables to pass into the command
    power_on: ''  # String specifying the power on bash command
    power_off: '' # String specifying the power off bash command
    restart: ''   # String specifying the restart bash command
    status: ''    # String specifying the status bash command
    status_off_exit_code: 255 # [Optional] Specify the off exit code
```

The majority of the above parameters give scripts to be ran when the relevant end point is hit. These are bash scripts that executed within the environment the server was started in. It is therefore possible to store the relevant credentials within the environment to prevent hard coding them in a config.

The `variables` parameter is used to customise the command on a per node basis. They can be referenced using standard bash syntax: `$var1`, `$var2`, etc. The value is pulled from the nodes hash as described below.

API requests will always respond with a `success` boolean value based on the exit code of the script. An exit value of 0 is considered a successful request. To prevent the client applications from hanging, the scripts may choose to exit 0 before the action has fully completed. This means successful response only indicate the action was submitted correctly NOT that it has completed correctly. All non zero exit codes are considered failures with the following exception.

The `status` command has two exit codes that are considered "successes", 0 and `status_off_exit_code`. An exit code of 0 must be returned if the node is currently running. The `status_off_exit_code` defaults to 255 and must be returned if the node is offline. All other exit codes are failures and the state of the node is undetermined.

NOTE: `Starting` and `Stopping` States

The API only supports nodes in `on` or `off` power states. Transitionary states (such as `starting`/`stopping`) are not supported and can not be communicated through the API. In these cases, the `status` script should return a failure exit code but may return either 0 or `status_off_exit_code`. There is no preference for the last known state versus the likely future state.

#### Adding the Nodes

The `nodes` are also set within the `topology` config and are used to customise the bash commands. The generic layouts is:

```
nodes:
  my-first-node:
    platform: 'my-custom-platform'  # [Required] The platform the node is on
    var1: some-value                # Any number of arbitrary variables
    var2: some-other-value
    ...
    # name: my-first-node           # The 'name' variable is implicitly set from
                                    # the node key and can not be overridden

  aws-node:     # Example AWS node
    platform: aws
    ec2_id: i-xxxxxxxxxxxxx
    region: eu-west-1
    # name: aws-node

  azure-node:   # Example Azure node
    resource_group: my-demo-group
    # name: azure-node
```

The variables specified on the platform will preform a lookup against the nodes. This is primarily used to set some form of node identifier bash variable (e.g. `$ec2_id`) in the script. The exact keys depends on the `platform` configuration.

The node `name` is implicitly set so it can be used as a variable and can not be overridden.

### Setting Up Systemd

A basic `systemd` unit file can be found [here](support/power-server.service). The unit file will need to be tweaked according to where the application has been installed/configured. The unit needs to be stored within `/etc/systemd/system`.

## Starting the Server

The `puma` server daemon can be started manually with:

```
bin/puma -p <port> -e production -d \
         --redirect-stdout <stdout-log-file-path> \
         --redirect-stderr <stderr-log-file-path>
```

## Stopping the Server

The `puma` server daemon can be stopped manually by sending an interrupt:

```
kill -s SIGINT <puma-pid>
```

## Authentication

The API requires all requests to carry with a [jwt](https://jwt.io). Within the token either `user: true` or `admin: true` needs to be set.

The following `rake` tasks are used to generate tokens with 30 days expiry. Tokens from other sources will be accepted as long as they:
1. Where signed with the same shared secret, and
2. An [expiry claim](https://tools.ietf.org/html/rfc7519#section-4.1.4) has been made.

As the shared secret is environment dependant, the `RACK_ENV` must be set within your environment.

```
# Set the rack environment
export RACK_ENV=production

# Generate a user token
rake token:user
```

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Creative Commons Attribution-ShareAlike 4.0 License, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2019-present Alces Flight Ltd.

You should have received a copy of the license along with this work.
If not, see <http://creativecommons.org/licenses/by-sa/4.0/>.

![Creative Commons License](https://i.creativecommons.org/l/by-sa/4.0/88x31.png)

Power Server is licensed under a [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

Based on a work at [https://github.com/openflighthpc/openflight-tools](https://github.com/openflighthpc/openflight-tools).

This content and the accompanying materials are made available available
under the terms of the Creative Commons Attribution-ShareAlike 4.0
International License which is available at [https://creativecommons.org/licenses/by-sa/4.0/](https://creativecommons.org/licenses/by-sa/4.0/),
or alternative license terms made available by Alces Flight Ltd -
please direct inquiries about licensing to
[licensing@alces-flight.com](mailto:licensing@alces-flight.com).

Power Server is distributed in the hope that it will be useful, but
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF
TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR
PURPOSE. See the [Creative Commons Attribution-ShareAlike 4.0
International License](https://creativecommons.org/licenses/by-sa/4.0/) for more
details.
