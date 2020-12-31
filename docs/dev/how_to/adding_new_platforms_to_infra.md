# Adding New Platforms to Chef Infra

Adding a new platform to Chef Infra involves not just adding the platform to the `chef/chef` repo in GitHub, but also ensuring that the platform is supported in all of our ecosystem tooling. This document breaks down all the places we need to update to bring in a new platform.

## Adding the Build to Chef/Chef

### Pull Request Testing

When we add a new platform, if possible, we want to ensure that we test that platform on all Pull Requests to the `chef/chef` GitHub repository. There are a few places to update to accomplish this.

#### RubyDistros

We run RSpec tests against all Pull Requests to `chef/chef` using containers built from our [RubyDistros project](https://github.com/chef/rubydistros). These containers are built on various Linux distribution releases and target the last few Ruby releases. This allows us to run RSpec tests on common Linux platforms like CentOS 8 with Ruby releases such as 2.7 or 3.0.

For major new Linux or Windows distribution releases, you'll want to add these to the RubyDistros repository. You can test these builds locally in Docker and then set the builds to run on DockerHub. If you're not a member of the [RubyDistros DockerHub org](https://hub.docker.com/orgs/rubydistros) then ask #releng-support to add you to that. From there you can add a new repository matching the existing repository setups. Make sure you configure the automated builds to point to the correct Dockerfile path with each Ruby version as a tag. See https://hub.docker.com/repository/docker/rubydistros/opensuse-15 for an example of how we set this up.

Note: Windows builds can't be built on DockerHub and have to be pushed manually from your workstation instead.

Once you've added the distro to RubyDistros and the image is pushed to DockerHub, you can add that new distro to the `chef/chef` [verify.pipeline.yml](https://github.com/chef/chef/blob/master/.expeditor/verify.pipeline.yml).

#### Kitchen Dokken Images

We utilize the kitchen-dokken Test Kitchen plugin to test the contents of `chef/chef` against various Linux distributions. This works best when run against containers that look more like VMs and less like slim containers. The [dokken-images](https://github.com/test-kitchen/dokken-images) repository defines many Docker images for common Linux distributions. These are all based on the official distro Docker images but contain additional packages to make them behave more like full systems.

Similar to the RubyDistros setup, these are defined in GitHub and built-in DockerHub. You'll need to be a member of the [dokken DockerHub organization](https://hub.docker.com/orgs/dokken). If you don't have access to that please ask #releng-support to add you. Once you've added a distro to the GitHub repo you can add a new repository to that DockerHub Organization. Make sure to copy the automated builds settings and specify the correct path to the Dockerfile. Once that is complete and the image is pushed to DockerHub you can add the new test to `chef/chef`. You'll need to edit the [kitchen-test/kitchen.yml](https://github.com/chef/chef/blob/master/kitchen-tests/kitchen.yml) file and then add that new platform to the [verify.pipeline.yml](https://github.com/chef/chef/blob/master/.expeditor/verify.pipeline.yml) config.

#### Azure Pipelines tests

COMING SOON!

### Omnibus Pipeline

With the new platform tested in Pull Requests, you'll now want to ensure that we build and test these packages in our Buildkite Omnibus pipeline.

HOW TO DO THIS COMING SOON!

### Code Changes

With builds in place, we also want to make sure we support this new platform within the Chef Infra Client itself. Most of this is not something that can be documented here. You'll just need to understand where in Chef Infra Client we need to support a new distro. The two most common places to add support are `Ohai` and `chef-utils`:

#### chef-utils

chef-utils provides a large number of helpers for making cookbook authoring simpler. One of the most useful sets of helpers is helpers for platforms and platform families, which will need to be updated if we added new distros. Make sure new platform are supported in `platform.rb` / `platform_family.rb` files in [chef-utils/lib/chef-utils/dsl](https://github.com/chef/chef/tree/master/chef-utils/lib/chef-utils/dsl). In order to test these changes you'll most likely need to update the Fauxhai data. See the section below for instructions on updating that data.

#### Ohai

Ohai powers all system configuration detection for Chef Infra Client. New distributions have pretty far-reaching impacts on Ohai and should be evaluated carefully. The most basic task when adding a new distro is to make sure that the platform is properly mapped to the appropriate platform_family value. On Linux systems this is performed in the [Linux Platform Plugin](https://github.com/chef/ohai/blob/master/lib/ohai/plugins/linux/platform.rb).

## Additional Ecosystem Updates

### Bento Boxes

COMING SOON!

### Fauxhai Dumps

COMING SOON!