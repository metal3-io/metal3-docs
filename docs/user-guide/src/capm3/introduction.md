# Kubernetes Cluster API Provider Metal3

Kubernetes-native declarative infrastructure for Metal3.

<div>
    <img src="../images/metal3-color.svg" width="120px" />
</div>

## What is the Cluster API Provider Metal3

The [Cluster API](https://github.com/kubernetes-sigs/cluster-api/) brings declarative,
Kubernetes-style APIs to cluster creation, configuration and management. The API
itself is shared across multiple cloud providers. Cluster API Provider Metal3 is
one of the providers for Cluster API and enables users to deploy a Cluster API based
cluster on top of bare metal infrastructure using Metal3.

## Compatibility with Cluster API

| CAPM3 version | Cluster API version | CAPM3 Release |
|---------------|---------------------|---------------|
| ~~v1alpha4~~  | ~~v1alpha3~~        | ~~v0.4.X~~    |
| ~~v1alpha5~~  | ~~v1alpha4~~        | ~~v0.5.X~~    |
| v1beta1       | v1beta1             | v1.1.X        |
| v1beta1       | v1beta1             | v1.2.X        |

## Development Environment

There are multiple ways to setup a development environment:

- [Using Tilt](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/dev-setup.md#tilt-development-environment)
- [Other management cluster](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/dev-setup.md#development-using-Kind-or-Minikube)
- See [metal3-dev-env](https://github.com/metal3-io/metal3-dev-env) for an
  end-to-end development and test environment for
  `cluster-api-provider-metal3` and
  [baremetal-operator](https://github.com/metal3-io/baremetal-operator).

## Getting involved and contributing

Are you interested in contributing to Cluster API Provider Metal3? We, the maintainers and community, would love your suggestions, contributions, and help! Also, the maintainers can be contacted at any time to learn more about how to get involved.

To set up your environment checkout the [development environment](#development-environment).

In the interest of getting more new people involved, we tag issues with [good first issue](https://github.com/metal3-io/cluster-api-provider-metal3/labels/good%20first%20issue). These are typically issues that have smaller scope but are good ways to start to get acquainted with the codebase.

We also encourage ALL active community participants to act as if they are maintainers, even if you don’t have "official" write permissions. This is a community effort, we are here to serve the Kubernetes community. If you have an active interest and you want to get involved, you have real power! Don’t assume that the only people who can get things done around here are the "maintainers".

We also would love to add more “official” maintainers, so show us what you can do!

All the repositories in the Metal3 project, including the Cluster API Provider Metal3 GitHub repository, use the Kubernetes bot commands. The full list of the commands can be found [here.](https://go.k8s.io/bot-commands) Note that some of them might not be implemented in metal3 CI.

## Community

Community resources and contact details can be found [here.](https://github.com/metal3-io/metal3-docs#community)

## Github issues

We use Github issues to keep track of bugs and feature requests.
There are two different templates to help ensuring that relevant information is included.

### Bugs

If you think you have found a bug please follow the instructions below.

- Please spend a small amount of time giving due diligence to the issue tracker. Your issue might be a duplicate.
- Collect logs from relevant components and make sure to include them in the [bug report](https://github.com/metal3-io/cluster-api-provider-metal3/issues/new?assignees=&labels=&template=bug_report.md) you are going to open.
- Remember users might be searching for your issue in the future, so please give it a meaningful title to help others.
- Feel free to reach out to the metal3 [community](#community).

### Tracking new features

We also use the issue tracker to track features. If you have an idea for a feature, or think you can help Cluster API Provider Metal3 become even more awesome, then follow the steps below.

- Open a [feature request.](https://github.com/metal3-io/cluster-api-provider-metal3/issues/new?template=feature_request.md)
- Remember users might be searching for your feature request in the future, so please give it a meaningful title to help others.
- Clearly define the use case, using concrete examples. e.g.: `I type this and cluster-api-provider-metal3 does that.`
- Some of our larger features will require proposals. If you would like to include a technical design for your feature please open a feature proposal in [metal3-docs](https://github.com/metal3-io/metal3-docs) using [this template](https://github.com/metal3-io/metal3-docs/blob/main/design/_template.md).

After the new feature is well understood, and the design agreed upon we can start coding the feature. We would love for you to code it. So please open up a WIP (work in progress) pull request, and happy coding.
